![Shenzhen](https://raw.github.com/mattt/nomad-cli.com/assets/shenzhen-banner.png)

Create `.ipa` files and then distribute them with [TestFlight](https://testflightapp.com/) or [HockeyApp](http://www.hockeyapp.net), all from the command line!

Less cumbersome than clicking around in Xcode, and less hassle than rolling your own build script--Shenzhen radically improves the process of getting new builds out to testers and enterprises.

> `shenzhen` is named for [深圳](http://en.wikipedia.org/wiki/Shenzhen), the Chinese city famous for its role as the center of manufacturing for a majority of consumer electronics, including iPhones and iPads.
> It's part of a series of world-class command-line utilities for iOS development, which includes [Cupertino](https://github.com/mattt/cupertino) (Apple Dev Center management), [Houston](https://github.com/mattt/houston) (Push Notifications), [Venice](https://github.com/mattt/venice) (In-App Purchase Receipt Verification), and [Dubai](https://github.com/mattt/dubai) (Passbook pass generation).

## Installation

    $ gem install shenzhen

## Usage

Shenzhen adds the `ipa` command to your PATH:

    $ ipa

      Build and distribute iOS apps (.ipa files)

      Commands:
        build                 Create a new .ipa file for your app
        distribute:testflight Distribute an .ipa file over TestFlight
        distribute:hockeyapp  Distribute an .ipa file over HockeyApp
        distribute:ftp        Distribute an .ipa file over FTP
        help                  Display global or [command] help documentation.

      Aliases:
        distribute           distribute:testflight

      Global Options:
        -h, --help           Display help documentation
        -v, --version        Display version information
        -t, --trace          Display backtrace when an error occurs

### Building & Distribution

    $ cd /path/to/iOS Project/
    $ ipa build
    $ ipa distribute

## Contact

Mattt Thompson

- http://github.com/mattt
- http://twitter.com/mattt
- m@mattt.me

## License

Shenzhen is available under the MIT license. See the LICENSE file for more info.
