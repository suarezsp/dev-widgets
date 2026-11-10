import DevWidgetsLinuxShell
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
guard let options = LaunchOptions.parse(arguments) else {
    print(LaunchOptions.USAGE)
    exit(arguments == ["--help"] ? 0 : 2)
}
let app = LinuxApp(options: options)
exit(app.run())
