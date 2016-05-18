//
//  FeedParser.swift
//  FeedParser
//
//  Created by Nuno Dias on 15/05/16.
//
//

import Foundation


public class FeedParser: NSObject, NSXMLParserDelegate {
    
    // MARK: - Private properties
    
    /// The current feed being parsed.
    private var feed: RSS2Feed? = RSS2Feed()
    
    /// The current feed item being parsed.
    private var feedItem: RSS2FeedChannelItem?
    
    /// The current path along the XML's DOM elements. Path components are updated to reflect the current XML element being parsed. e.g. "/rss/channel/title" mean it's currently parsing the channels `<title>` element.
    private var currentXMLDOMPath: NSURL? = NSURL(string: "/")
    
    // FIXME: - The `XMLParser` property should not be an optional property and the delegate should be set by the time the Parser has been initialized. Fix this when the specified initializer bug has been fix in a new swift release.
    /// The XML parser.
    private var XMLParser: NSXMLParser?
    
    private var finished: ((feed: RSS2Feed?) -> ())?
    
    // MARK: - Initializers
    
    /**
     Initializes the parser with the XML content referenced by the given URL.
     
     - parameter URL: An NSURL object specifying a URL
     
     - returns: An instance of the feed parser.
     */
    // FIXME: - Convert to a failable initializer and return nil in `assertionFailure` when a fix is released for the compiler error "All stored properties of a class instance must be initialized before returning nil from an initializer"
    // See: http://stackoverflow.com/a/26497229/1544047
    public init(URL: NSURL) {
        
        guard let parser = NSXMLParser(contentsOfURL: URL) else {
            assertionFailure("Unable to initialize the parser with the provided URL: \(URL)")
            return
        }
        
        self.XMLParser = parser
        
    }
    
    // MARK: - Public methods
    
    /**
     Starts parsing the feed.
     */
    public func parse(finished: (feed: RSS2Feed?) -> ()) {
        self.finished = finished
        self.XMLParser?.delegate = self
        self.XMLParser?.parse()
    }
    
    
    // MARK: - NSXMLParser delegate
    
    public func parserDidStartDocument(parser: NSXMLParser) {
        Debug.log("parser: \(parser), didStartDocument")
    }
    
    public func parserDidEndDocument(parser: NSXMLParser) {
        Debug.log("parser: \(parser), didEndDocument")
        self.finished?(feed: self.feed)
    }
    
    public func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        Debug.log("parser: \(parser.debugDescription), didStartElement: \(elementName), namespaceURI: \(namespaceURI), qualifiedName: \(qName), attributeDict: \(attributeDict)")
        
        // Update the current path along the XML's DOM elements by appending the new component with `elementName`
        self.currentXMLDOMPath = self.currentXMLDOMPath?.URLByAppendingPathComponent(elementName)
        
        guard let element = RSS2FeedElement(rawValue: self.currentXMLDOMPath?.absoluteString ?? "") else {
            Debug.log("Unable to infer XML DOM element from current path: '\(self.currentXMLDOMPath)'")
            return
        }
        
        self.map(attributes: attributeDict, toFeed: self.feed!, forElement: element)
        
        
    }
    
    public func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        Debug.log("parser: \(parser.debugDescription), didEndElement: \(elementName), namespaceURI: \(namespaceURI), qualifiedName: \(qName)")
        
        // Update the current path along the XML's DOM elements by deleting last component
        self.currentXMLDOMPath = self.currentXMLDOMPath?.URLByDeletingLastPathComponent
        
    }
    
    public func parser(parser: NSXMLParser, foundCDATA CDATABlock: NSData) {
        Debug.log("parser: \(parser.debugDescription), foundCDATA: \(CDATABlock.debugDescription)")
        
        guard let string = NSString(data: CDATABlock, encoding: NSUTF8StringEncoding) as? String else {
            assertionFailure("Unable to convert the bytes in `CDATABlock` to Unicode characters using the encoding provided at current path: \(self.currentXMLDOMPath)")
            return
        }
        
        if let element = RSS2FeedElement(rawValue: self.currentXMLDOMPath?.absoluteString ?? "") {
            self.map(string, toFeed: self.feed!, forElement: element)
        }
            
        else if let dublinCoreElement = DublinCoreElement(rawValue: self.currentXMLDOMPath?.absoluteString ?? "") {
            self.map(string, toFeed: self.feed!, forElement: dublinCoreElement)
        }
            
        else if let contentElement = ContentElement(rawValue: self.currentXMLDOMPath?.absoluteString ?? "") {
            self.map(string, toFeed: self.feed!, forElement: contentElement)
        }
            
        else {
            assertionFailure("Undefined element for current path: \(self.currentXMLDOMPath)")
        }
        
    }
    
    public func parser(parser: NSXMLParser, foundCharacters string: String) {
        Debug.log("parser: \(parser.debugDescription), foundCharacters: \(string)")
        
        if let feedElement = RSS2FeedElement(rawValue: self.currentXMLDOMPath?.absoluteString ?? "") {
            self.map(string, toFeed: self.feed!, forElement: feedElement)
        }
            
        else if let syndicationElement = SyndicationElement(rawValue: self.currentXMLDOMPath?.lastPathComponent ?? "") {
            self.map(string, toFeed: self.feed!, forElement: syndicationElement)
        }
            
        else if let dublinCoreElement = DublinCoreElement(rawValue: self.currentXMLDOMPath?.absoluteString ?? "") {
            self.map(string, toFeed: self.feed!, forElement: dublinCoreElement)
        }
            
        else {
            Debug.log("Undefined element for current path: \(self.currentXMLDOMPath)")
        }
        
    }
    
    
    // MARK: - NSXMLParser delegate errors
    
    public func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        Debug.log("parser: \(parser), parseErrorOccurred: \(parseError.debugDescription)")
    }
    
    public func parser(parser: NSXMLParser, validationErrorOccurred validationError: NSError) {
        Debug.log("parser: \(parser), validationErrorOccurred: \(validationError.debugDescription)")
    }
    
    
}