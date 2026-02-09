# hpc-sorting-serious-game

HPC serious game showcasing how collaborative effort between processes and threads can speedup sorting. The game should support Android as a platform first.
12

## Test at

<https://siponek.github.io/hpc-sorting-serious-game/>
<img
  src="https://github.com/user-attachments/assets/9c20c587-473e-4156-b35f-ec1cb567b055"
  alt="obraz"
  style="max-width: 100%; height: auto;"
/>

## Installation

### Play though browser

- [Just open the link above in your](<https://siponek.github.io/hpc-sorting-serious-game/>) chrome browser and start playing

### Windows prerequisites

You need to have the following software installed to run the game on windows

- Google Chrome [LINK To chrome download page](https://www.google.com/intl/en_en/chrome/)
- Chocolatey [LINK To chocolatey download page](https://chocolatey.org/install)
  - To install chocolatey run this command inside powershell with admin privileges

    ```powershell
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    ```

- Python 3.12.11 (for webserver and signaling server)
  - Install python using chocolatey

    ```powershell
    choco install python --version=3.12.11
    ```

  Then you can close the terminal and open it again to have chocolatey in your path

  - Install uv for your global python (for project management, an alternative to pipenv or poetry)
  
    ```powershell
    pip install uv
    ```

  - Install just (for project automation, an alternative to __make__)

    ```powershell
    choco install just
    ```

### Run locally

- Clone the repository

  ```pwsh
  git clone https://github.com/Siponek/hpc-sorting-serious-game.git
  ```

- Move to the project directory

  ```pwsh
  cd hpc-sorting-serious-game
  ```

- Install the dependencies using just and uv

  ```pwsh
  just sync
  ```

- Start game locally
  - For __singleplayer__ just start the webserver

    ```pwsh
    just test-web-local
      ```

    OR just drag exports\web-export\index.html to your chrome browser

  - For __multiplayer__ start the signaling server and webserver

    ```pwsh
    just signaling-server
    ```

    In a separate terminal tab

    ```pwsh
    just test-web-local
    ```

  You can open the game now [http://localhost:8000](http://localhost:8000)

### Make sure to run the game on separate tabs in chrome, since tabs might freeze in the background for other players

## FAQ

Export to windows need to use [rcedit](https://github.com/electron/rcedit/releases) and [for icon](https://docs.godotengine.org/en/stable/tutorials/export/changing_application_icon_for_windows.html)
[Export from godot](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
