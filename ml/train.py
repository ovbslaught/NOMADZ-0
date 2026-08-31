"""
NOMADZ-0 RL training entry point.

Usage (once the project has an exported headless build and
environments/2_5d_metroidvania/ai/AIController.gd is attached to Player.tscn):

    pip install -r requirements.txt
    python train.py --env_path ../builds/nomadz_headless --timesteps 2_000_000

If --env_path is omitted, godot_rl_agents connects to an already-running
editor instance instead (useful for debugging one env at a time).
"""
import argparse

from godot_rl.core.godot_env import GodotEnv
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import CheckpointCallback


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--env_path", type=str, default=None,
                    help="Path to exported headless game binary. Omit to attach to a running editor.")
    p.add_argument("--n_parallel", type=int, default=4,
                    help="Parallel env instances (only used with --env_path).")
    p.add_argument("--timesteps", type=int, default=1_000_000)
    p.add_argument("--speedup", type=int, default=8,
                    help="Engine.time_scale multiplier during training.")
    p.add_argument("--checkpoint_dir", type=str, default="checkpoints")
    return p.parse_args()


def main():
    args = parse_args()

    env = StableBaselinesGodotEnv(
        env_path=args.env_path,
        n_parallel=args.n_parallel if args.env_path else 1,
        speedup=args.speedup,
    )

    model = PPO(
        "MultiInputPolicy",
        env,
        verbose=1,
        n_steps=2048,
        batch_size=256,
        tensorboard_log="./tb_logs",
    )

    checkpoint_cb = CheckpointCallback(
        save_freq=50_000,
        save_path=args.checkpoint_dir,
        name_prefix="nomadz_ppo",
    )

    model.learn(total_timesteps=args.timesteps, callback=checkpoint_cb)
    model.save(f"{args.checkpoint_dir}/nomadz_ppo_final")
    env.close()


if __name__ == "__main__":
    main()
