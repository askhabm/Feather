# Feather

Feather is a sideloading utility app for iOS and macOS that allows you to install unsigned IPA files on your device. By utilizing a locally hosted server, you can deploy your app installations securely and efficiently.

## Features

- Installs unsigned IPA files to your device, so you can use your own test builds
- Install tweaks to system applications
- Supports injecting `.deb` and `.dylib` files.
- Actively maintained: always ensuring most apps get installed properly.
- No tracking or analytics, ensuring user privacy.
- Of course, open source and free.

## Download

Visit [releases](https://github.com/claration/Feather/releases) and get the latest `.ipa`.

<a href="https://celloserenity.github.io/altdirect/?url=https://raw.githubusercontent.com/claration/Feather/refs/heads/main/app-repo.json" target="_blank">
   <img src="https://github.com/CelloSerenity/altdirect/blob/main/assets/png/AltSource_Blue.png?raw=true" alt="Add AltSource" width="200">
</a>
<a href="https://github.com/claration/Feather/releases/latest/download/Feather.ipa" target="_blank">
   <img src="https://github.com/CelloSerenity/altdirect/blob/main/assets/png/Download_Blue.png?raw=true" alt="Download .ipa" width="200">
</a>

## Translating

Impactor now has translation support, all localizations are located in `Feather/Resources/Localizable.xcstrings`.

To add a new language, open Xcode and use the interface to add/contribute to languages.

To properly contribute and test potentially test localizations, you can head over to the [contributing guide](./CONTRIBUTING.md).

## Sponsors

| Thanks to all my [sponsors](https://github.com/sponsors/claration)!! |
|:--------------------------------------------------------------------:|
| <img src="https://sponsors.claration.dev/sponsors.png">              |
| _**"samara is cute" - Vendicated**_                                  |

## Acknowledgements

- [Samara](https://github.com/claration) - The maker
- [idevice](https://github.com/jkcoxson/idevice) - Backend for builds with this included, used for communication with `installd`.
- [*.sslip.io](https://sslip.io/) - localhost with public CA signed SSL certificate
- [Vapor](https://github.com/vapor/vapor) - A server-side Swift HTTP web framework.
- [Zsign](https://github.com/zhlynn/zsign) - Allowing to sign on-device, reimplimented to work on other platforms such as iOS.
- [LiveContainer](https://github.com/LiveContainer/LiveContainer) - Fixes/some help
- [Nuke](https://github.com/kean/Nuke) - Image caching.
- [Asspp](https://github.com/Lakr233/Asspp) - Some code for setting up the http server.
- [plistserver](https://github.com/nekohaxx/plistserver) - Hosted on https://api.palera.in.

## License 

This project is licensed under the GPL-3.0 license. You can see the full details of the license [here](https://github.com/claration/Feather/blob/main/LICENSE). It's under this specific license because I wanted to make a project that is transparent to the user thats related to certificate paired sideloading, before this project there weren't any open source projects that filled in this gap.

By contributing to this project, you agree to license your code under the GPL-3.0 license as well (including agreeing to license exceptions), ensuring that your work, like all other contributions, remains freely accessible and open.
