Animation Usage:
1. With a model loaded from the previous method, drag the PSO2AQM_IO script into 3ds max and hit Load PSO2 Anim
2. Pick an .aqm for your model
3. Done. Shouldn't take very long, but larger animations can obviously be a moment.

Exporting animations for custom models: 
1. Export the AQN or AQP+AQN of the model at least once or assign user properties manually.
2. Load in animation data to scene if not loaded.
3. Export PSO2 Anim with default settings. 

Advanced AQM I/O Usage Notes:
-Clear Anim Data on Load attempts to clear animation frames on models before importing a new animation. Usually works, but worst case, just reload the model to its bind pose.
-Y-Z Flip Anim should match what you used for Y-Z Axis Flip on model import. Pretty self explanatory.
-Ignore Standard Translation Keys is for models like the mini rappy suit. Most things will not need this, but otherwise you'll get models like Pikachu using Captain Falcon's Brawl animations.
-Match bone names is for attempting to match animations to models that don't normally use them. This will likely be screwy, but can probably be useful with manual correction. Worst case, it will probably be funny.
-Base Scale is to match up with the Rescale option in import script. As models scaled using the model importer are scaled as they are made rather than after via the root bone, this helps to ensure things match up.
-Heeled Outfit? is basically for player models with heels. If you click it, you can edit the value manually, but otherwise it will do its best to calculate the value for you based on your model. Keep in mind Y-Z Flip Anim will affect this and assumes you have the correct setting.

