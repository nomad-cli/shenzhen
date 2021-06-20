![Shenzhen](https://raw.github.com/nomad/nomad.github.io/assets/shenzhen-banner.png)

----

**Note**: shenzhen uses the Xcode 6 build API, which has been deprecated for almost 3 years now. This causes problems if your app makes use of Swift 3, watchOS and other app targets. 

A maintained alternative to build your iOS apps is [gym](https://fastlane.tools/gym) which uses the latest Xcode API. To distribute builds, you can use [fastlane](https://fastlane.tools). More information on how to get started is available on the [iOS Beta deployment guide](https://docs.fastlane.tools/getting-started/ios/beta-deployment/).

----

Create `.ipa` files and distribute them from the command line, using any of the following methods:

- [iTunes Connect](https://itunesconnect.apple.com)
- [HockeyApp](http://hockeyapp.net/)
- [Beta by Crashlytics](http://try.crashlytics.com/beta/)
- [RivieraBuild](http://rivierabuild.com)
- [TestFairy](https://www.testfairy.com/)
- [DeployGate](https://deploygate.com)
- [Fly It Remotely (FIR.im)](http://fir.im)
- [蒲公英 (PGYER)](http://www.pgyer.com)
- [Amazon S3](http://aws.amazon.com/s3/)
- FTP / SFTP

Less cumbersome than clicking around in Xcode, and less hassle than rolling your own build script, Shenzhen radically improves the process of getting new builds out to testers and enterprises.

> `shenzhen` is named for [深圳](https://en.wikipedia.org/wiki/Shenzhen), the Chinese city famous for being the center of manufacturing for a majority of consumer electronics, including iPhones and iPads.
> It's part of a series of world-class command-line utilities for iOS development, which includes [Cupertino](https://github.com/nomad/cupertino) (Apple Dev Center management), [Houston](https://github.com/nomad/houston) (Push Notifications), [Venice](https://github.com/nomad/venice) (In-App Purchase Receipt Verification), [Dubai](https://github.com/nomad/dubai) (Passbook pass generation), and [Nashville](https://github.com/nomad/nashville) (iTunes Store API).

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
    build                       Create a new .ipa file for your app
    distribute:rivierabuild     Distribute an .ipa file over [RivieraBuild](http://rivierabuild.com)
    distribute:hockeyapp        Distribute an .ipa file over HockeyApp
    distribute:crashlytics      Distribute an .ipa file over Crashlytics
    distribute:deploygate       Distribute an .ipa file over deploygate
    distribute:fir              Distribute an .ipa file over fir.im
    distribute:itunesconnect    Upload an .ipa file to iTunes Connect for review
    distribute:pgyer            Distribute an .ipa file over Pgyer
    distribute:ftp              Distribute an .ipa file over FTP
    distribute:s3               Distribute an .ipa file over Amazon S3
    distribute:testfairy        Distribute an .ipa file over TestFairy
    info                        Show mobile provisioning information about an .ipa file
    help                        Display global or [command] help documentation.

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

#### RivieraBuild Distribution

```
$ ipa distribute:rivierabuild -k API_TOKEN -a AVAILABILITY
```

> Shenzhen will load credentials from the environment variable `RIVIERA_API_TOKEN` unless otherwise specified.
> To get the list of availability options, visit http://api.rivierabuild.com

#### HockeyApp Distribution

```
$ ipa distribute:hockeyapp -a API_TOKEN
```

> Shenzhen will load credentials from the environment variable `HOCKEYAPP_API_TOKEN` unless otherwise specified.

#### TestFairy Distribution

```
$ ipa distribute:testfairy -a API_KEY
```

> Shenzhen will load credentials from the environment variable `TESTFAIRY_API_KEY` unless otherwise specified.

#### Crashlytics Beta Distribution

```
$ ipa distribute:crashlytics -c /path/to/Crashlytics.framework -a API_TOKEN -s BUILD_SECRET
```

> Shenzhen will load credentials from the environment variables `CRASHLYTICS_API_TOKEN` & `CRASHLYTICS_BUILD_SECRET`, and attempt to run the submit executable `submit` in the path to Crashlytics.framework specified by `CRASHLYTICS_FRAMEWORK_PATH` unless otherwise specified.


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

> Shenzhen will load credentials from the environment variables `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_REGION` unless otherwise specified.

#### FIR (Fly it Remotely)

```
$ ipa distribute:fir -u USER_TOKEN -a APP_ID
```

> Shenzhen will load credentials from the environment variables `FIR_USER_TOKEN`, `FIR_APP_ID` unless otherwise specified.

#### 蒲公英 (PGYER)

```
$ ipa distribute:pgyer -u USER_KEY -a APP_KEY
```

> Shenzhen will load credentials from the environment variables `PGYER_USER_KEY`, `PGYER_API_KEY` unless otherwise specified.


#### iTunes Connect Distribution

```
$ ipa distribute:itunesconnect -a me@email.com -p myitunesconnectpassword -i appleid --upload
```

> Shenzhen will load credentials from the environment variables `ITUNES_CONNECT_ACCOUNT` and `ITUNES_CONNECT_PASSWORD` unless otherwise specified. If only an account is provided, the keychain will be searched for a matching entry.
>
> The `-i` (or `--apple-id`) flag is "An automatically generated ID assigned to your app". It can be found via iTunes Connect by navigating to:
> * My Apps -> [App Name] -> More -> About This App -> Apple ID
>
> For a fully hands-free upload, in a CI environment for example, ensure your iTunes Connect credentials are stored in your keychain, and that the keychain item has the Validation app in its 'Always allow access' list.  Running Shenzhen once with the `--save-keychain` flag, and clicking `Always Allow` on the prompt will set this up for you.

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

## License

Shenzhen is released under an MIT license. See LICENSE for more information.
