# hpc-sorting-serious-game

HPC serious game showcasing how collaborative effort between processes and threads can speedup sorting. The game should support Android as a platform first.
12
## Test at
https://siponek.github.io/hpc-sorting-serious-game/

## Reqiuirements
- chrome
- python (for webserver and signaling server)

## FAQ

Export to windows need to use [rcedit](https://github.com/electron/rcedit/releases) and [for icon](https://docs.godotengine.org/en/stable/tutorials/export/changing_application_icon_for_windows.html)
[Export from godot](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)

### No communication between nodes

The problem lies with the default setting for GDSync. By default, it block communication between nodes. To enable communication, disable "proteected mode" in Project -> Tools -> GDSync. This will allow nodes to communicate with each other.
![Project -> Tools -> GDSync](GDSync-protected.png)
