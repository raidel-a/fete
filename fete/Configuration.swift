import Foundation

enum Configuration {
    enum Error: Swift.Error, CustomStringConvertible {
        case missingKey
        case invalidValue
        
        var description: String {
            switch self {
            case .missingKey:
                return "Configuration key not found in Info.plist"
            case .invalidValue:
                return "Configuration value is invalid or empty"
            }
        }
    }

    static func value<T>(for key: String) throws -> T where T: LosslessStringConvertible {
        print("Loading configuration for key: \(key)")
        
        guard let object = Bundle.main.object(forInfoDictionaryKey: key) else {
            print("❌ Key '\(key)' not found in Info.plist")
            throw Error.missingKey
        }
        
        print("📦 Raw value from Info.plist for '\(key)': \(String(describing: object))")

        switch object {
        case let value as T:
            print("✅ Direct cast successful for '\(key)': \(value)")
            return value
        case let string as String:
            guard let value = T(string) else {
                print("❌ Could not convert '\(string)' to type \(T.self)")
                throw Error.invalidValue
            }
            print("✅ String conversion successful for '\(key)': \(value)")
            return value
        default:
            print("❌ Invalid value type for '\(key)': \(type(of: object))")
            throw Error.invalidValue
        }
    }
} 