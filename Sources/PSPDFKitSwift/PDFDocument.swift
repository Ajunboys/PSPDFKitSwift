import PSPDFKit.Private
import Foundation
import CoreFoundation

class PDFDocument: PSPDFDocument, Codable {
    typealias FileIndex = UInt

    override init(dataProviders: [PSPDFDataProviding], loadCheckpointIfAvailable loadCheckpoint: Bool) {
        super.init(dataProviders: dataProviders, loadCheckpointIfAvailable: loadCheckpoint)
    }

    // Disable Directory based options in favor of typed options.
    @available(*, unavailable)
    override func save(options: [PSPDFDocumentSaveOption : Any]? = nil, completionHandler: ((Error?, [PSPDFAnnotation]) -> Void)? = nil) { fatalError() }

    // Disable Directory based options in favor of typed options.
    @available(*, unavailable)
    override func save(options: [PSPDFDocumentSaveOption : Any]? = nil) throws { fatalError() }

    //TODO: NS_SWIFT_NAME
    override func fileName(for fileIndex: FileIndex) -> String {
        return super.fileName(for: UInt(fileIndex))
    }

    // MARK: - Codable, NSCoding

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
    }

    enum CodingKeys: String, CodingKey {
        case uid
        case title
        case areAnnotationsEnabled
        case dataProviders
        case shouldLoadCheckpoint
        case renderOptionsForAll
        case renderOptionsForPage
        case renderOptionsForProcessor
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let dataProviders = try container.decode(Array<PSPDFDataProviding>.self, forKey: .dataProviders)
        let enableCheckpoints = try container.decode(Bool.self, forKey: .shouldLoadCheckpoint)

        super.init(dataProviders: dataProviders, loadCheckpointIfAvailable: enableCheckpoints)

        title = try container.decode(String.self, forKey: .title)
        areAnnotationsEnabled = try container.decode(Bool.self, forKey: .title)
        uid = try container.decode(String.self, forKey: .uid)

        //TODO: Refine PSPDFRenderOption dictionary
        setRenderOptions(try container.decode([PSPDFRenderOption: Any]?.self, forKey: .renderOptionsForAll), type: .all)
        setRenderOptions(try container.decode([PSPDFRenderOption: Any]?.self, forKey: .renderOptionsForAll), type: .page)
        setRenderOptions(try container.decode([PSPDFRenderOption: Any]?.self, forKey: .renderOptionsForProcessor), type: .processor)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(dataProviders, forKey: .dataProviders)
        try container.encode(title, forKey: .title)
        try container.encode(areAnnotationsEnabled, forKey: .areAnnotationsEnabled)
        try container.encode(uid, forKey: .uid)
        try container.encode(checkpointer.checkpointExists, forKey: .shouldLoadCheckpoint)
        try container.encode(renderOptions(for: .all, context: nil), forKey: .renderOptionsForAll)
        try container.encode(renderOptions(for: .page, context: nil), forKey: .renderOptionsForPage)
        try container.encode(renderOptions(for: .processor, context: nil), forKey: .renderOptionsForProcessor)
    }
}

// MARK: - Saving
extension PDFDocument {
    public typealias DocumentPermissions = PSPDFDocumentPermissions

    public struct SecurityOptions {
        var ownerPassword: String?
        var userPassword: String?
        var keyLength: Int
        var permissions: DocumentPermissions
        var encryptionAlgorithm: PSPDFDocumentEncryptionAlgorithm
    }

    public enum SaveOption {
        case security(SecurityOptions)
        case forceRewrite

        internal var dictionary: [PSPDFDocumentSaveOption: Any]  {
            switch self {
            case .security(let securityOptions):
                return [.securityOptions: securityOptions]
            case .forceRewrite:
                return [.forceRewrite: NSNumber(value: true)]
            }
        }

        internal static func mapToDictionary(options: [SaveOption]) -> [PSPDFDocumentSaveOption: Any] {
            var optionsDictionary = [PSPDFDocumentSaveOption: Any]()
            for option in options {
                option.dictionary.forEach { optionsDictionary[$0.0] = $0.1 }
            }
            return optionsDictionary
        }
    }

    
    ///  Saves the document and all of its linked data, including bookmarks and
    ///  annotations, synchronously.
    ///
    /// - Parameter options: See `SaveOption` documentation for more details.
    /// - Throws: NSInternalInconsistencyException if save options are not valid.
    public func save(options: SaveOption...) throws {
        try super.save(options: SaveOption.mapToDictionary(options: options))
    }

    /// Saves the document and all of its linked data, including bookmarks and
    /// annotations, asynchronously. Does not block the calling thread.
    ///
    /// - Parameters:
    ///   - options: See `SaveOption` documentation for more details.
    ///   - completion: Called on the *main thread* after the save operation finishes.
    public func save(options: SaveOption..., completion: @escaping (Result<[PSPDFAnnotation], AnyError>) -> Void)  {
        super.save(options: SaveOption.mapToDictionary(options: options), completionHandler: { (error, annotations) in
            if let error = error {
                completion(Result.failure(AnyError(error)))
                return
            }

            completion(Result.success(annotations))
        })
    }
}

internal class PDFDocumentTests {
    static func test() throws {
        let document = PDFDocument()
        document.title = "lambada"
        let securityOptions = PDFDocument.SecurityOptions(ownerPassword: "foo", userPassword: "bar", keyLength: 16, permissions: [.extract, .fillForms], encryptionAlgorithm: .AES)
        try document.save(options: .security(securityOptions), .forceRewrite)
        document.save(options: .security(securityOptions), .forceRewrite) { (result) in
            do {
                let annotations = try result.dematerialize()
                print(annotations)
            } catch {
                print(error)
            }
        }
    }
}
