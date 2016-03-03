#!/usr/bin/env xcrun swift
import Cocoa

func loadResolvedCartfile(file: String) throws -> String {
    let string = try String(contentsOfFile: file, encoding: NSUTF8StringEncoding)
    return string
}

func parseResolvedCartfile(contents: String) -> [CartfileEntry] {
    let lines = contents.componentsSeparatedByString("\n")
    return lines.filter({ $0.utf16.count > 0 }).map { CartfileEntry(line: $0) }
}

struct CartfileEntry: CustomStringConvertible {
    let name: String, version: String
    var license: String?

    init(line: String) {
        let line = line.stringByReplacingOccurrencesOfString("github ", withString: "")
        let components = line.componentsSeparatedByString("\" \"")
        name = components[0].stringByReplacingOccurrencesOfString("\"", withString: "")
        version = components[1].stringByReplacingOccurrencesOfString("\"", withString: "")
    }

    var projectName: String {
        return name.componentsSeparatedByString("/")[1]
    }

    var description: String {
        return ([name, version] + licenseURLStrings).joinWithSeparator(" ")
    }

    var licenseURLStrings: [String] {
        return ["Source/License.txt", "License.md", "LICENSE.md", "LICENSE", "License.txt", "LICENSE.txt"].map { "https://github.com/\(self.name)/raw/\(self.version)/\($0)" }
    }

    func fetchLicense(outputDir: String) -> String {
        var license = ""
        let urls = licenseURLStrings.map({ NSURL(string: $0)! })
        print("Fetching licenses for \(name) ...")
        for url in urls {
            let semaphore = dispatch_semaphore_create(0)

            let request = NSURLRequest(URL: url)
            let task = NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { (data, response, error) -> Void in
                dispatch_semaphore_signal(semaphore)
                if let response = response as? NSHTTPURLResponse {
                    if response.statusCode == 404 {
                        return
                    }
                }

                let string = NSString(data: data!, encoding: NSUTF8StringEncoding)
                if let string = string {
                    license = string as String
                }
            })
            task.resume()
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        }

        return license
    }
}

if Process.arguments.count == 3 {
    let resolvedCartfile = Process.arguments[1]
    let outputDirectory = Process.arguments[2]
    var error: NSError?
    do {
        let content = try loadResolvedCartfile(resolvedCartfile)
        let entries = parseResolvedCartfile(content)
        let licenses = entries.map { ["Type": "PSGroupSpecifier", "Title": $0.projectName, "FooterText": $0.fetchLicense(outputDirectory)] }
        let fileName = (outputDirectory as NSString).stringByAppendingPathComponent("Licenses.plist")
        let data = ["PreferenceSpecifiers": licenses]
        (data as NSDictionary).writeToFile(fileName, atomically: true)
        print("Super awesome! Your licenses are at \(fileName) 🍻")
    } catch {
        print(error)
    }
} else {
    print("USAGE: ./fetch_licenses Cartfile.resolved output_directory/")
}
