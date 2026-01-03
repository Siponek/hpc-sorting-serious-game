# hpc-sorting-serious-game

HPC serious game showcasing how collaborative effort between processes and threads can speedup sorting. The game should support Android as a platform first.
12
## Test at
https://siponek.github.io/hpc-sorting-serious-game/
<img width="1501" height="839" alt="obraz" src="https://github.com/user-attachments/assets/9c20c587-473e-4156-b35f-ec1cb567b055" />

## Reqiuirements for singleplayer
- chrome (tested on chrome
## Requirements for multiplayer
- python (for webserver and signaling server)
  - uv (for project management)

## How to start

In justfile there is a command for starting the webserver and signaling server. (This is not needed when playing alone!)

```justfile
[multiplayer]
signaling-server             # Start the WebRTC signaling server for web multiplayer
signaling-server-port port   # Start signaling server on a custom port
test-multiplayer             # Start both signaling server and web server for full multiplayer testing
```

Install python dependencies using
```bash
uv sync
```

Run build with just command (or you can just start the servers using uv run)
```just
just test-multiplayer
```

Make sure to run the game on separate tabs in chrome, since tabs might freeze in the background

## FAQ

Export to windows need to use [rcedit](https://github.com/electron/rcedit/releases) and [for icon](https://docs.godotengine.org/en/stable/tutorials/export/changing_application_icon_for_windows.html)
[Export from godot](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)

### No communication between nodes

The problem lies with the default setting for GDSync. By default, it block communication between nodes. To enable communication, disable "proteected mode" in Project -> Tools -> GDSync. This will allow nodes to communicate with each other.
![Project -> Tools -> GDSync](GDSync-protected.png)
