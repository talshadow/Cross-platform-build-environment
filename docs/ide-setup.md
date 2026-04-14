# Налаштування IDE

Проєкт повністю підтримує CMakePresets.json — обидві IDE підхоплюють пресети
автоматично. `CMAKE_EXPORT_COMPILE_COMMANDS=ON` (встановлено у базовому пресеті)
генерує `compile_commands.json` для коректного IntelliSense при крос-компіляції.

---

## Qt Creator

### Вимоги

Qt Creator **7.0+** з вбудованою підтримкою CMakePresets.json.  
Перевірка версії: *Help → About Qt Creator*.

### Відкриття проєкту

1. *File → Open File or Project* → обрати `CMakeLists.txt`
2. Qt Creator знайде `CMakePresets.json` і запропонує список конфігурацій.
3. Відмітити потрібні пресети (наприклад `ubuntu2404-debug`, `rpi4-release`) →
   *Configure Project*.

> Якщо пресети не з'явились — переконайтесь що `CMakePresets.json` лежить
> поруч із `CMakeLists.txt` і версія Qt Creator ≥ 7.0.

### Додавання CMake змінних (sysroot тощо)

*Projects* (ліва панель) → обрати конфігурацію → розділ **CMake** →
кнопка **Add** → вписати змінну і значення:

| Ім'я змінної   | Значення              |
|----------------|-----------------------|
| `RPI_SYSROOT`  | `/srv/rpi4-sysroot`   |
| `BUILD_ROOT`   | `/mnt/nvme/proj`      |

Після зміни — натиснути **Apply Configuration Changes**.

> Альтернатива без зміни `CMakePresets.json`: створити `CMakeUserPresets.json`
> у корені проєкту (він у `.gitignore`):
> ```json
> {
>   "version": 6,
>   "configurePresets": [
>     {
>       "name": "rpi4-release-local",
>       "inherits": "rpi4-release",
>       "cacheVariables": {
>         "RPI_SYSROOT": "/srv/rpi4-sysroot"
>       }
>     }
>   ]
> }
> ```

### Kit для крос-компіляції

Qt Creator за замовчуванням може не знайти крос-компілятор у Kit.  
Якщо конфігурація CMake завершується з помилкою про компілятор:

1. *Edit → Preferences → Kits → Compilers → Add → GCC → C*
   - Compiler path: `/usr/bin/aarch64-linux-gnu-gcc-12` (або `-13` для RPi 5)
   - ABI: `aarch64-linux-generic-elf-64bit`
2. Аналогічно для C++: `/usr/bin/aarch64-linux-gnu-g++-12`
3. *Kits → Add* (або відредагувати існуючий):
   - C compiler: щойно доданий
   - C++ compiler: щойно доданий
   - CMake Tool: системний або Kitware
4. У конфігурації проєкту обрати цей Kit.

Для нативних пресетів (`ubuntu2404-debug` тощо) Kit з системним GCC
підходить без додаткових кроків.

### Збірка і запуск

- *Build → Build Project* або `Ctrl+B`
- Вибір пресету: *Projects → Build & Run → активна конфігурація*
- Вибір цільового виконавця: *Projects → Run Settings*

### Налаштування Remote Linux (debug на RPi)

1. *Edit → Preferences → Devices → Add → Generic Linux Device*:
   - Host: `192.168.1.100`
   - User: `pi`
   - Authentication: ключ SSH або пароль
2. *Projects → Run Settings → Add → Custom Executable*:
   - Remote host: обраний пристрій
   - Executable: `/home/pi/my_app`
3. Для GDB remote debug: *Debug → Start Debugging → Attach to Running Debug Server*,
   або використовуйте *Run → Deploy* (якщо налаштований deploy step).

### IntelliSense (code model)

Qt Creator використовує clangd або власний парсер. `compile_commands.json`
генерується у `build/<presetName>/compile_commands.json`.

Qt Creator підхоплює його автоматично при відкритті проєкту через CMake.
Якщо підсвічування не працює — *Tools → C++ → Clangd → Reload*
або *Build → Run CMake*.

---

## Visual Studio Code

### Розширення

Встановити через *Extensions* (`Ctrl+Shift+X`):

| Розширення | Publisher | Призначення |
|---|---|---|
| **CMake Tools** | Microsoft | Робота з CMake пресетами, збірка |
| **C/C++** | Microsoft | IntelliSense, debug (GDB) |
| **clangd** *(опційно)* | LLVM | Альтернативний IntelliSense через compile_commands.json |
| **Remote - SSH** *(опційно)* | Microsoft | Розробка безпосередньо на RPi |

> Якщо використовуєте clangd — вимкніть IntelliSense C/C++ розширення
> (`"C_Cpp.intelliSenseEngine": "disabled"` у settings.json), щоб уникнути
> конфлікту.

### Відкриття проєкту

```bash
code /path/to/SupportRaspberryPI
```

CMake Tools автоматично знаходить `CMakePresets.json`.  
При першому відкритті: *CMake Tools* запитає *Select Configure Preset* у
нижній статусній панелі — обрати потрібний пресет.

### Вибір пресету

**Через статусну панель** (внизу вікна):

```
[CMake: rpi4-release]  [Build]  [Debug]
```

Натиснути на назву пресету → з'явиться список → обрати інший.

**Через командну палітру** (`Ctrl+Shift+P`):

```
CMake: Select Configure Preset
CMake: Select Build Preset
```

### Налаштування .vscode/settings.json

Створіть `.vscode/settings.json` (або додайте до існуючого):

```json
{
    "cmake.useCMakePresets": "always",
    "cmake.copyCompileCommands": "${workspaceFolder}/compile_commands.json",

    "C_Cpp.default.compileCommands": "${workspaceFolder}/compile_commands.json",
    "C_Cpp.default.intelliSenseMode": "linux-gcc-arm64",

    "cmake.buildDirectory": "${workspaceFolder}/build/${cmake.activePresetName}",
    "cmake.installPrefix": ""
}
```

> `cmake.copyCompileCommands` копіює `compile_commands.json` з директорії
> збірки у корінь проєкту після кожної конфігурації — clangd і C/C++
> розширення знаходять його автоматично.

**При крос-компіляції** IntlliSense режим залежить від цільової архітектури:

| Платформа | `intelliSenseMode` |
|---|---|
| RPi 4 / 5 (AArch64) | `linux-gcc-arm64` |
| RPi 2 (ARMv7) | `linux-gcc-arm` |
| Ubuntu x86_64 | `linux-gcc-x64` |

Або використовуйте clangd — він читає `compile_commands.json` і визначає
архітектуру автоматично.

### Передача CMake змінних (sysroot)

**Варіант 1 — CMakeUserPresets.json** (рекомендовано, файл у `.gitignore`):

```json
{
  "version": 6,
  "configurePresets": [
    {
      "name": "rpi4-release-local",
      "displayName": "RPi 4 Release (local sysroot)",
      "inherits": "rpi4-release",
      "cacheVariables": {
        "RPI_SYSROOT": "/srv/rpi4-sysroot",
        "BUILD_ROOT": "/mnt/nvme/proj"
      }
    }
  ],
  "buildPresets": [
    {
      "name": "rpi4-release-local",
      "configurePreset": "rpi4-release-local",
      "jobs": 0
    }
  ]
}
```

Після збереження файлу новий пресет `rpi4-release-local` з'явиться у
списку CMake Tools автоматично.

**Варіант 2 — settings.json** (глобально для всіх пресетів):

```json
{
    "cmake.configureArgs": [
        "-DRPI_SYSROOT=/srv/rpi4-sysroot"
    ]
}
```

### Збірка

- `Ctrl+Shift+B` → *CMake: Build*
- Або через командну палітру: *CMake: Build*
- Або кнопка `[Build]` у статусній панелі

### Налаштування завдань (tasks.json)

`.vscode/tasks.json` для зручного запуску збірки:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "CMake: Configure rpi4-release",
      "type": "shell",
      "command": "cmake --preset rpi4-release -DRPI_SYSROOT=/srv/rpi4-sysroot",
      "group": "build",
      "problemMatcher": "$gcc"
    },
    {
      "label": "CMake: Build rpi4-release",
      "type": "shell",
      "command": "cmake --build --preset rpi4-release",
      "group": { "kind": "build", "isDefault": true },
      "dependsOn": "CMake: Configure rpi4-release",
      "problemMatcher": "$gcc"
    },
    {
      "label": "Deploy to RPi",
      "type": "shell",
      "command": "./scripts/deploy.sh --preset rpi4-release --host 192.168.1.100 --user pi",
      "group": "none"
    }
  ]
}
```

### Debug на RPi (GDB remote)

`.vscode/launch.json` для remote GDB:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "RPi4: Remote GDB",
      "type": "cppdbg",
      "request": "launch",
      "program": "${workspaceFolder}/build/rpi4-relwithdebinfo/my_app",
      "miDebuggerPath": "/usr/bin/aarch64-linux-gnu-gdb",
      "miDebuggerServerAddress": "192.168.1.100:2345",
      "cwd": "${workspaceFolder}",
      "stopAtEntry": false,
      "externalConsole": false,
      "MIMode": "gdb",
      "setupCommands": [
        {
          "description": "Вказати sysroot для пошуку бібліотек",
          "text": "set sysroot /srv/rpi4-sysroot",
          "ignoreFailures": true
        },
        {
          "description": "Pretty printing",
          "text": "-enable-pretty-printing",
          "ignoreFailures": true
        }
      ],
      "preLaunchTask": "Deploy to RPi"
    }
  ]
}
```

На RPi запустіть GDB server перед дебагом:

```bash
# На Raspberry Pi
gdbserver :2345 /home/pi/my_app
```

### Remote - SSH (розробка безпосередньо на RPi)

Якщо хочете редагувати і збирати код прямо на RPi:

1. Встановіть розширення *Remote - SSH*
2. `Ctrl+Shift+P` → *Remote-SSH: Connect to Host* → `pi@192.168.1.100`
3. VS Code відкриє нове вікно підключене до RPi
4. Відкрийте папку проєкту на RPi
5. Збірка буде нативна (без крос-компіляції)

---

## Спільне для обох IDE: compile_commands.json

При **крос-компіляції** `compile_commands.json` містить прапори цільового
компілятора (`aarch64-linux-gnu-gcc -mcpu=cortex-a72 ...`). IntelliSense
і clangd використовують цей файл і розуміють AArch64-специфічні заголовки.

Якщо одночасно є кілька конфігурацій (rpi4 + ubuntu2404) — обирайте
`compile_commands.json` від тієї, де ведете основну розробку.
Для нативних пресетів (ubuntu2404-debug) IntelliSense буде точнішим,
оскільки host і target збігаються.
