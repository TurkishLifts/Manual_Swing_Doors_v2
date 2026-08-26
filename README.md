# Manual_Swing_Doors_v2
This is the continuation of Manual_Swing_Doors, which was getting difficult to maintain & add more features. You can fully customize the swing doors via the Config script located inside the plugin.

Important: You must set every door timer to math.huge, as the plugin automatically closes the inner doors only when the swing door is shut and a call is active. Additionally, ensure that invisible Front_Doors are added to every floor with a swing door.

## Getting Started
To build the plugin from scratch, use:

```bash
rojo build plugin.project.json -o Dist/Manual_Swing_Doors_v2.rbxm
```

Next, open `Manual_Swing_Doors_v2.rbxm` in Roblox Studio and start the Rojo server:

```bash
rojo serve
```

For more help, check out [the Rojo documentation](https://rojo.space/docs).