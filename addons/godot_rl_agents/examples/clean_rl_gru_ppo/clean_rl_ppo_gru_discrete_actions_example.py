# docs and experiment results can be found at https://docs.cleanrl.dev/rl-algorithms/ppo/#ppo_atari_lstmpy based on
# https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ppo_atari_lstm.py Modified to work with GDRL,
# vector observation space, use GRU/Vanilla RNN with checkpoint saving/basic inference added, and other changes.
# Hyperparameter defaults have been changed, feel free to adjust as needed.

import os
import pathlib
import random
import sys
import time
from collections import deque
from dataclasses import dataclass
from typing import Optional

import gymnasium as gym
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
import tyro
from torch.distributions.categorical import Categorical
from torch.utils.tensorboard import SummaryWriter

from godot_rl.wrappers.clean_rl_wrapper import CleanRLGodotEnv


@dataclass
class Args:
    env_path: str = None
    """Path to the Godot exported environment"""
    n_parallel: int = 1
    """How many instances of the environment executable to
    launch (requires --env_path to be set if > 1)."""
    viz: bool = False
    """Whether the exported Godot environment will displayed during training"""
    speedup: int = 8
    """How much to speed up the environment"""
    use_vanilla_rnn: bool = False
    """If False, will use nn.GRU. If True, will use nn.RNN instead."""
    exp_name: str = os.path.basename(__file__)[: -len(".py")]
    """the name of this experiment"""
    seed: int = 1
    """seed of the experiment"""
    torch_deterministic: bool = True
    """if toggled, `torch.backends.cudnn.deterministic=False`"""
    cuda: bool = True
    """if toggled, cuda will be enabled by default"""
    save_model_frequency_global_steps: Optional[int] = None
    """Saves model after every n global steps (NOTE: Setting too low can cause many/frequent writes to storage).
    If less than 10, will error, but note that 10 could still be too frequent in many cases."""
    load_model_path: str = None
    """Where to load agent from"""
    inference: bool = False
    """Inference only mode (needs load_model_path set)"""
    track: bool = False
    """if toggled, this experiment will be tracked with Weights and Biases"""
    wandb_project_name: str = "cleanRL"
    """the wandb's project name"""
    wandb_entity: str = None
    """the entity (team) of wandb's project"""
    capture_video: bool = False
    """whether to capture videos of the agent performances (check out `videos` folder)"""

    # Algorithm specific arguments
    env_id: str = "GodotRLEnv"
    """the id of the environment"""
    total_timesteps: int = 15_000_000
    """total timesteps of the experiments"""
    learning_rate: float = 3e-4
    """the learning rate of the optimizer"""
    num_envs: int = 1
    """the number of parallel game environments [note: automatically set]"""
    num_steps: int = 1024
    """the number of steps to run in each environment per policy rollout"""
    anneal_lr: bool = True
    """Toggle learning rate annealing for policy and value networks"""
    gamma: float = 0.99
    """the discount factor gamma"""
    gae_lambda: float = 0.95
    """the lambda for the general advantage estimation"""
    num_minibatches: int = 1
    """the number of mini-batches"""
    update_epochs: int = 60
    """the K epochs to update the policy"""
    norm_adv: bool = True
    """Toggles advantages normalization"""
    clip_coef: float = 0.15
    """the surrogate clipping coefficient"""
    clip_vloss: bool = False
    """Toggles whether or not to use a clipped loss for the value function, as per the paper."""
    ent_coef: float = 0.005
    """coefficient of the entropy"""
    vf_coef: float = 0.5
    """coefficient of the value function"""
    max_grad_norm: float = 0.5
    """the maximum norm for the gradient clipping"""
    target_kl: float = 0.0065
    """the target KL divergence threshold"""

    # to be filled in runtime
    batch_size: int = 0
    """the batch size (computed in runtime)"""
    minibatch_size: int = 0
    """the mini-batch size (computed in runtime)"""
    num_iterations: int = 0
    """the number of iterations (computed in runtime)"""


def layer_init(layer, std=np.sqrt(2), bias_const=0.0):
    torch.nn.init.orthogonal_(layer.weight, std)
    torch.nn.init.constant_(layer.bias, bias_const)
    return layer


class Agent(nn.Module):
    def __init__(self, envs):
        super().__init__()
        self.network = nn.Sequential(
            layer_init(nn.Linear(np.array(envs.single_observation_space.shape).prod(), 64)),
            nn.Tanh(),
            layer_init(nn.Linear(64, 64)),
            nn.Tanh(),
        )
        self.rnn = nn.RNN(64, 64) if args.use_vanilla_rnn else nn.GRU(64, 64)
        for name, param in self.rnn.named_parameters():
            if "bias" in name:
                nn.init.constant_(param, 0)
            elif "weight" in name:
                nn.init.orthogonal_(param, 1.0)

        self.actor = layer_init(nn.Linear(64, envs.single_action_space.n), std=0.01)
        self.critic = layer_init(nn.Linear(64, 1), std=1)

    def get_states(self, x, rnn_state, done):
        hidden = self.network(x)

        # RNN logic
        batch_size = rnn_state.shape[1]
        hidden = hidden.reshape((-1, batch_size, self.rnn.input_size))
        done = done.reshape((-1, batch_size))
        new_hidden = []
        for h, d in zip(hidden, done):
            h, rnn_state = self.rnn(h.unsqueeze(0), (1.0 - d).view(1, -1, 1) * rnn_state)
            new_hidden += [h]
        new_hidden = torch.flatten(torch.cat(new_hidden), 0, 1)
        return new_hidden, rnn_state

    def get_value(self, x, rnn_state, done):
        hidden, _ = self.get_states(x, rnn_state, done)
        return self.critic(hidden)

    def get_action_and_value(self, x, rnn_state, done, action=None):
        hidden, rnn_state = self.get_states(x, rnn_state, done)
        logits = self.actor(hidden)
        probs = Categorical(logits=logits)
        if action is None:
            action = probs.sample()
        return action, probs.log_prob(action), probs.entropy(), self.critic(hidden), rnn_state


def maybe_load_agent() -> Optional[Agent]:
    if args.load_model_path is None:
        return None
    print("Loading model: " + os.path.abspath(args.load_model_path))
    agent_state_dict = torch.load(pathlib.Path(args.load_model_path), map_location=device, weights_only=True)
    new_agent = Agent(envs).to(device)
    new_agent.load_state_dict(agent_state_dict)
    new_agent.eval()
    return new_agent


def save_agent(filename: str = ""):
    log_dir = writer.get_logdir()
    path = (pathlib.Path(log_dir) / filename).with_suffix(".pt")
    print("Saving model: " + os.path.abspath(path))
    torch.save(agent.state_dict(), path)


if __name__ == "__main__":
    args = tyro.cli(Args)

    if args.save_model_frequency_global_steps and args.save_model_frequency_global_steps <= 10:
        raise ValueError("save_frequency is below 10. This would likely save too frequently.")

    # env setup
    envs = env = CleanRLGodotEnv(
        env_path=args.env_path,
        show_window=args.viz,
        speedup=args.speedup,
        seed=args.seed,
        n_parallel=args.n_parallel,
    )
    args.num_envs = envs.num_envs
    assert isinstance(envs.single_action_space, gym.spaces.Discrete), "only discrete action space is supported"

    if args.inference:
        device = torch.device("cuda" if torch.cuda.is_available() and args.cuda else "cpu")

        if not args.load_model_path:
            print("Inference requires load_model_path to be set.")
            sys.exit(1)
        inference_agent = maybe_load_agent()
        if not inference_agent:
            print("Failed to load model. Can't proceed with inference.")
            sys.exit(1)

        next_rnn_state = torch.zeros(inference_agent.rnn.num_layers, args.num_envs, inference_agent.rnn.hidden_size).to(
            device
        )
        next_obs, _ = envs.reset(seed=args.seed)
        next_obs = torch.Tensor(next_obs).to(device)
        next_done = torch.zeros(args.num_envs).to(device)
        for i in range(args.total_timesteps):
            with torch.no_grad():
                action, logprob, _, value, next_rnn_state = inference_agent.get_action_and_value(
                    next_obs, next_rnn_state, next_done
                )
            next_obs, reward, terminations, truncations, infos = envs.step(action.cpu().numpy())
            next_done = np.logical_or(terminations, truncations)
            next_obs, next_done = torch.Tensor(next_obs).to(device), torch.Tensor(next_done).to(device)
        sys.exit(0)

    args.batch_size = int(args.num_envs * args.num_steps)
    args.minibatch_size = int(args.batch_size // args.num_minibatches)
    args.num_iterations = args.total_timesteps // args.batch_size
    run_name = f"{args.env_id}__{args.exp_name}__{args.seed}__{int(time.time())}"
    if args.track:
        import wandb

        wandb.init(
            project=args.wandb_project_name,
            entity=args.wandb_entity,
            sync_tensorboard=True,
            config=vars(args),
            name=run_name,
            monitor_gym=True,
            save_code=True,
        )
    writer = SummaryWriter(f"runs/{run_name}")
    writer.add_text(
        "hyperparameters",
        "|param|value|\n|-|-|\n%s" % ("\n".join([f"|{key}|{value}|" for key, value in vars(args).items()])),
    )

    # TRY NOT TO MODIFY: seeding
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    torch.backends.cudnn.deterministic = args.torch_deterministic

    device = torch.device("cuda" if torch.cuda.is_available() and args.cuda else "cpu")

    agent = Agent(envs).to(device)
    optimizer = optim.Adam(agent.parameters(), lr=args.learning_rate, eps=1e-5)

    # ALGO Logic: Storage setup
    obs = torch.zeros((args.num_steps, args.num_envs) + envs.single_observation_space.shape).to(device)
    actions = torch.zeros((args.num_steps, args.num_envs) + envs.single_action_space.shape).to(device)
    logprobs = torch.zeros((args.num_steps, args.num_envs)).to(device)
    rewards = torch.zeros((args.num_steps, args.num_envs)).to(device)
    dones = torch.zeros((args.num_steps, args.num_envs)).to(device)
    values = torch.zeros((args.num_steps, args.num_envs)).to(device)

    # TRY NOT TO MODIFY: start the game
    global_step = 0
    start_time = time.time()
    next_obs, _ = envs.reset(seed=args.seed)
    next_obs = torch.Tensor(next_obs).to(device)
    next_done = torch.zeros(args.num_envs).to(device)
    next_rnn_state = torch.zeros(agent.rnn.num_layers, args.num_envs, agent.rnn.hidden_size).to(device)

    # episode reward stats, modified as Godot RL does not return this information in info (yet)
    episode_returns = deque(maxlen=40)
    accum_rewards = np.zeros(args.num_envs)

    # tracks how many steps have elapsed since the last model saved
    global_steps_since_save = 0

    for iteration in range(1, args.num_iterations + 1):
        # initial_rnn_state = (next_rnn_state[0].clone(), next_rnn_state[1].clone())
        initial_rnn_state = next_rnn_state.clone()
        # Annealing the rate if instructed to do so.
        if args.anneal_lr:
            frac = 1.0 - (iteration - 1.0) / args.num_iterations
            lrnow = frac * args.learning_rate
            optimizer.param_groups[0]["lr"] = lrnow

        for step in range(0, args.num_steps):
            save_frequency: Optional[int] = args.save_model_frequency_global_steps
            if save_frequency:
                if global_steps_since_save >= save_frequency:
                    save_agent(str(global_step) + "_steps")
                    global_steps_since_save = 0
                global_steps_since_save += args.num_envs

            global_step += args.num_envs
            obs[step] = next_obs
            dones[step] = next_done

            # ALGO LOGIC: action logic
            with torch.no_grad():
                action, logprob, _, value, next_rnn_state = agent.get_action_and_value(
                    next_obs, next_rnn_state, next_done
                )
                values[step] = value.flatten()
            actions[step] = action
            logprobs[step] = logprob

            # TRY NOT TO MODIFY: execute the game and log data.
            next_obs, reward, terminations, truncations, infos = envs.step(action.cpu().numpy())
            next_done = np.logical_or(terminations, truncations)
            rewards[step] = torch.tensor(reward).to(device).view(-1)
            next_obs, next_done = torch.Tensor(next_obs).to(device), torch.Tensor(next_done).to(device)

            accum_rewards += np.array(reward)

            for i, d in enumerate(next_done):
                if d:
                    episode_returns.append(accum_rewards[i])
                    accum_rewards[i] = 0

        # bootstrap value if not done
        with torch.no_grad():
            next_value = agent.get_value(
                next_obs,
                next_rnn_state,
                next_done,
            ).reshape(1, -1)
            advantages = torch.zeros_like(rewards).to(device)
            lastgaelam = 0
            for t in reversed(range(args.num_steps)):
                if t == args.num_steps - 1:
                    nextnonterminal = 1.0 - next_done
                    nextvalues = next_value
                else:
                    nextnonterminal = 1.0 - dones[t + 1]
                    nextvalues = values[t + 1]
                delta = rewards[t] + args.gamma * nextvalues * nextnonterminal - values[t]
                advantages[t] = lastgaelam = delta + args.gamma * args.gae_lambda * nextnonterminal * lastgaelam
            returns = advantages + values

        # flatten the batch
        b_obs = obs.reshape((-1,) + envs.single_observation_space.shape)
        b_logprobs = logprobs.reshape(-1)
        b_actions = actions.reshape((-1,) + envs.single_action_space.shape)
        b_dones = dones.reshape(-1)
        b_advantages = advantages.reshape(-1)
        b_returns = returns.reshape(-1)
        b_values = values.reshape(-1)

        # Optimizing the policy and value network
        assert args.num_envs % args.num_minibatches == 0
        envsperbatch = args.num_envs // args.num_minibatches
        envinds = np.arange(args.num_envs)
        flatinds = np.arange(args.batch_size).reshape(args.num_steps, args.num_envs)
        clipfracs = []
        for epoch in range(args.update_epochs):
            np.random.shuffle(envinds)
            for start in range(0, args.num_envs, envsperbatch):
                end = start + envsperbatch
                mbenvinds = envinds[start:end]
                mb_inds = flatinds[:, mbenvinds].ravel()  # be really careful about the index

                _, newlogprob, entropy, newvalue, _ = agent.get_action_and_value(
                    b_obs[mb_inds],
                    # (initial_rnn_state[0][:, mbenvinds], initial_rnn_state[1][:, mbenvinds]),
                    initial_rnn_state[:, mbenvinds],
                    b_dones[mb_inds],
                    b_actions.long()[mb_inds],
                )
                logratio = newlogprob - b_logprobs[mb_inds]
                ratio = logratio.exp()

                with torch.no_grad():
                    # calculate approx_kl http://joschu.net/blog/kl-approx.html
                    old_approx_kl = (-logratio).mean()
                    approx_kl = ((ratio - 1) - logratio).mean()
                    clipfracs += [((ratio - 1.0).abs() > args.clip_coef).float().mean().item()]

                mb_advantages = b_advantages[mb_inds]
                if args.norm_adv:
                    mb_advantages = (mb_advantages - mb_advantages.mean()) / (mb_advantages.std() + 1e-8)

                # Policy loss
                pg_loss1 = -mb_advantages * ratio
                pg_loss2 = -mb_advantages * torch.clamp(ratio, 1 - args.clip_coef, 1 + args.clip_coef)
                pg_loss = torch.max(pg_loss1, pg_loss2).mean()

                # Value loss
                newvalue = newvalue.view(-1)
                if args.clip_vloss:
                    v_loss_unclipped = (newvalue - b_returns[mb_inds]) ** 2
                    v_clipped = b_values[mb_inds] + torch.clamp(
                        newvalue - b_values[mb_inds],
                        -args.clip_coef,
                        args.clip_coef,
                    )
                    v_loss_clipped = (v_clipped - b_returns[mb_inds]) ** 2
                    v_loss_max = torch.max(v_loss_unclipped, v_loss_clipped)
                    v_loss = 0.5 * v_loss_max.mean()
                else:
                    v_loss = 0.5 * ((newvalue - b_returns[mb_inds]) ** 2).mean()

                entropy_loss = entropy.mean()
                loss = pg_loss - args.ent_coef * entropy_loss + v_loss * args.vf_coef

                optimizer.zero_grad()
                loss.backward()
                nn.utils.clip_grad_norm_(agent.parameters(), args.max_grad_norm)
                optimizer.step()

            if args.target_kl is not None and approx_kl > args.target_kl:
                break

        y_pred, y_true = b_values.cpu().numpy(), b_returns.cpu().numpy()
        var_y = np.var(y_true)
        explained_var = np.nan if var_y == 0 else 1 - np.var(y_true - y_pred) / var_y

        # TRY NOT TO MODIFY: record rewards for plotting purposes
        writer.add_scalar("charts/learning_rate", optimizer.param_groups[0]["lr"], global_step)
        writer.add_scalar("losses/value_loss", v_loss.item(), global_step)
        writer.add_scalar("losses/policy_loss", pg_loss.item(), global_step)
        writer.add_scalar("losses/entropy", entropy_loss.item(), global_step)
        writer.add_scalar("losses/old_approx_kl", old_approx_kl.item(), global_step)
        writer.add_scalar("losses/approx_kl", approx_kl.item(), global_step)
        writer.add_scalar("losses/clipfrac", np.mean(clipfracs), global_step)
        writer.add_scalar("losses/explained_variance", explained_var, global_step)
        print("SPS:", int(global_step / (time.time() - start_time)))
        print(f"Approx KL: {approx_kl.item():.4f}")
        if len(episode_returns) > 0:
            print(
                "Returns (Last 40 episodes) Mean:",
                np.mean(np.array(episode_returns)),
                "Max:",
                np.max(np.array(episode_returns)),
                "Min:",
                np.min(np.array(episode_returns)),
            )
            writer.add_scalar("charts/episodic_return", np.mean(np.array(episode_returns)), global_step)
        print("---")
        writer.add_scalar("charts/SPS", int(global_step / (time.time() - start_time)), global_step)

    envs.close()
    writer.close()
