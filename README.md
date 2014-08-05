![Shenzhen](https://raw.github.com/mattt/nomad-cli.com/assets/shenzhen-banner.png)

Create `.ipa` files and then distribute them with [TestFlight](https://testflightapp.com/) or [HockeyApp](http://www.hockeyapp.net) or [DeployGate](https://deploygate.com), all from the command line!

Less cumbersome than clicking around in Xcode, and less hassle than rolling your own build script--Shenzhen radically improves the process of getting new builds out to testers and enterprises.

> `shenzhen` is named for [深圳](http://en.wikipedia.org/wiki/Shenzhen), the Chinese city famous for its role as the center of manufacturing for a majority of consumer electronics, including iPhones and iPads.
> It's part of a series of world-class command-line utilities for iOS development, which includes [Cupertino](https://github.com/mattt/cupertino) (Apple Dev Center management), [Houston](https://github.com/mattt/houston) (Push Notifications), [Venice](https://github.com/mattt/venice) (In-App Purchase Receipt Verification), and [Dubai](https://github.com/mattt/dubai) (Passbook pass generation).

## Installation

```
$ gem install shenzhen
```

### JSON Build Error

Users running Mac OS X Mavericks with Xcode 5.1 may encounter an error when attempting to install the `json` gem dependency. As per the [Xcode 5.1 Release Notes](https://developer.apple.com/library/ios/releasenotes/DeveloperTools/RN-Xcode/Introduction/Introduction.html):

> The Apple LLVM compiler in Xcode 5.1 treats unrecognized command-line options as errors. This issue has been seen when building both Python native extensions and Ruby Gems, where some invalid compiler options are currently specified.

To work around this, install the `json` gem first with the following command:

```
$ ARCHFLAGS=-Wno-error=unused-command-line-argument-hard-error-in-future gem install json
```

## Usage

> For best results, set your environment localization to UTF-8, with `$ export LC_ALL="en_US.UTF-8"`. Otherwise, Shenzhen may return unexpectedly with the error "invalid byte sequence in US-ASCII".

Shenzhen adds the `ipa` command to your PATH:

```
$ ipa

  Build and distribute iOS apps (.ipa files)

  Commands:
    build                 Create a new .ipa file for your app
    distribute:testflight Distribute an .ipa file over TestFlight
    distribute:hockeyapp  Distribute an .ipa file over HockeyApp
    distribute:deploygate Distribute an .ipa file over deploygate
    distribute:ftp        Distribute an .ipa file over FTP
    distribute:S3         Distribute an .ipa file over Amazon S3
    info                  Show mobile provisioning information about an .ipa file
    help                  Display global or [command] help documentation.

  Aliases:
    distribute           distribute:testflight

  Global Options:
    -h, --help           Display help documentation
    -v, --version        Display version information
    -t, --trace          Display backtrace when an error occurs
```

### Building & Distribution

```
$ cd /path/to/iOS Project/
$ ipa build
$ ipa distribute
```

#### TestFlight Distribution

```
$ ipa distribute:testflight -a API_TOKEN -T TEAM_TOKEN
```

> Shenzhen will load credentials from the environment variables `TESTFLIGHT_API_TOKEN` and `TESTFLIGHT_TEAM_TOKEN` unless otherwise specified.

#### HockeyApp Distribution

```
$ ipa distribute:hockeyapp --token API_TOKEN
```

> Shenzhen will load credentials from the environment variable `HOCKEYAPP_API_TOKEN` unless otherwise specified.

#### DeployGate Distribution

```
$ ipa distribute:deploygate -a API_TOKEN -u USER_NAME
```

> Shenzhen will load credentials from the environment variable `DEPLOYGATE_API_TOKEN` and `DEPLOYGATE_USER_NAME` unless otherwise specified.

#### FTP Distribution

```
$ ipa distribute:ftp --host HOST -u USER -p PASSWORD -P FTP_PATH
```

#### SFTP Distribution

```
$ ipa distribute:sftp --host HOST -u USER -p PASSWORD -P FTP_PATH
```

#### Amazon S3 Distribution

```
$ ipa distribute:s3 -a ACCESS_KEY_ID -s SECRET_ACCESS_KEY -b BUCKET
```

> Shenzhen will load credentials from the environment variable `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_REGION` unless otherwise specified.

### Displaying Embedded .mobileprovision Information

```
$ ipa info /path/to/app.ipa

+-----------------------------+----------------------------------------------------------+
| ApplicationIdentifierPrefix | DJ73OPSO53                                               |
| CreationDate                | 2014-03-26T02:53:00+00:00                                |
| Entitlements                | application-identifier: DJ73OPSO53.com.nomad.shenzhen    |
|                             | aps-environment: production                              |
|                             | get-task-allow: false                                    |
|                             | keychain-access-groups: ["DJ73OPSO53.*"]                 |
| CreationDate                | 2017-03-26T02:53:00+00:00                                |
| Name                        | Shenzhen                                                 |
| TeamIdentifier              | S6ZYP4L6TY                                               |
| TimeToLive                  | 172                                                      |
| UUID                        | P7602NR3-4D34-441N-B6C9-R79395PN1OO3                     |
| Version                     | 1                                                        |
+-----------------------------+----------------------------------------------------------+
```

## Contact

Mattt Thompson

- http://github.com/mattt
- http://twitter.com/mattt
- m@mattt.me

## License

Shenzhen is available under the MIT license. See the LICENSE file for more info.
