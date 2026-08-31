### CleanRL PPO GRU Discrete Actions example

This example is a modification of [CleanRL PPO Atari LSTM](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ppo_atari_lstm.py),
it's adjusted to work with GDRL and vector obs, along with adding inference, changing the default params, and other modifications.

You may need to install tyro using `pip install tyro`. If you get an error while running the script: `ModuleNotFoundError: No module named 'tyro'`, install it.

## Observations:
- Works with vector observations.

## Actions:
- Accepts a single discrete action space.

## CL arguments unique to this example:
### RNN settings:
By default, uses GRU. It can use vanilla RNN instead if you use the CL argument `--use_vanilla_rnn`

### Checkpoint saving:
Example: Save checkpoint every 500_000 steps: `--save_model_frequency_global_steps=500_000`.
If you don't set this argument, the model will not be saved, only the logs.
The checkpoints will be saved inside the `runs` folder in a different folder for each run, you will see the full path displayed in console when a checkpoint is saved.

### Inference:
Example use: `--load_model_path=path_to_saved_file.pt --inference` (set the true path to a checkpoint).

Other CL args should be similar to those described in https://github.com/edbeeching/godot_rl_agents/blob/main/docs/ADV_CLEAN_RL.md (but there is no onnx export/inference currently implemented for this example).
