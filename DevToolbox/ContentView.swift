//
//  ContentView.swift
//  DevToolbox
//
//  Created by ssg on 8/7/25.
//

import SwiftUI
import Foundation
import CryptoKit

// MARK: - Models
struct JSONNode: Identifiable {
    let id = UUID()
    let key: String?
    let value: Any
    let type: JSONType
    var children: [JSONNode] = []
    var isExpanded: Bool = true
    
    enum JSONType {
        case dictionary
        case array
        case string
        case number
        case boolean
        case null
        
        var displayName: String {
            switch self {
            case .dictionary: return "Object"
            case .array: return "Array"
            case .string: return "String"
            case .number: return "Number"
            case .boolean: return "Boolean"
            case .null: return "Null"
            }
        }
        
        var color: Color {
            switch self {
            case .dictionary: return .blue
            case .array: return .purple
            case .string: return .green
            case .number: return .orange
            case .boolean: return .pink
            case .null: return .gray
            }
        }
    }
}

// MARK: - Enums
enum ToolType: String, CaseIterable {
    case jsonFormatter = "JSON Formatter"
    case urlEncodeDecode = "URL Encode/Decode"
    case base64 = "Base64"
    case jwt = "JWT Decoder"
    case textCase = "Text Case"
    case hash = "Hash Generator"
    
    var icon: String {
        switch self {
        case .jsonFormatter: return "curlybraces"
        case .urlEncodeDecode: return "link"
        case .base64: return "lock"
        case .jwt: return "key"
        case .textCase: return "textformat"
        case .hash: return "number"
        }
    }
    
    var storageKey: String {
        return "input_\(self.rawValue.replacingOccurrences(of: " ", with: "_"))"
    }
}

enum ViewMode: String, CaseIterable {
    case text = "Text View"
    case tree = "Tree View"
}

enum ProcessMode: String, CaseIterable {
    case encode = "Encode"
    case decode = "Decode"
}

// MARK: - Main View
struct ContentView: View {
    @State private var selectedTool: ToolType?
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(ToolType.allCases, id: \.self, selection: $selectedTool) { tool in
                Label(tool.rawValue, systemImage: tool.icon)
                    .tag(tool as ToolType?)
            }
            .navigationTitle("Dev Toolbox")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
            #endif
        } detail: {
            // Detail view
            if let tool = selectedTool {
                ToolDetailView(selectedTool: tool)
                    .id(tool) // 이 줄 추가! - tool이 변경되면 View를 재생성
            } else {
                Text("Select a tool")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
        }
        #if os(macOS)
        .navigationSplitViewStyle(.balanced)
        #endif
    }
}

//MARK: - Detail view
struct ToolDetailView: View {
    let selectedTool: ToolType
    @AppStorage("viewMode") private var viewMode: ViewMode = .text
    @AppStorage("processMode_url") private var urlProcessMode: ProcessMode = .encode
    @AppStorage("processMode_base64") private var base64ProcessMode: ProcessMode = .encode
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var jsonNodes: [JSONNode] = []
    @State private var showCopiedAlert: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            VStack(spacing: 12) {
                HStack {
                    Text(selectedTool.rawValue)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Mode Picker
                    if selectedTool == .jsonFormatter {
                        Picker("View Mode", selection: $viewMode) {
                            ForEach(ViewMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    } else if selectedTool == .urlEncodeDecode {
                        Picker("Process Mode", selection: $urlProcessMode) {
                            ForEach(ProcessMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                        .onChange(of: urlProcessMode) { _, _ in
                            processInput()
                        }
                    } else if selectedTool == .base64 {
                        Picker("Process Mode", selection: $base64ProcessMode) {
                            ForEach(ProcessMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                        .onChange(of: base64ProcessMode) { _, _ in
                            processInput()
                        }
                    }
                }
                
                HStack {
                    Button(action: onClickClear) {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(inputText.isEmpty)
                    
                    Button(action: onClickCopy) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(outputText.isEmpty)
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color.customToolbarBackground)
            
            Divider()
            
            // Content area
            if selectedTool == .jsonFormatter && viewMode == .tree && !jsonNodes.isEmpty {
                // Tree view for JSON
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(jsonNodes) { node in
                            JSONTreeNodeView(node: node, level: 0)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.customBackground)
            } else {
                // Text-based view
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Input")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            TextEditor(text: $inputText)
                                .font(.system(.body, design: .monospaced))
                                .padding(4)
                                .background(Color.customBackground)
                                .cornerRadius(8)
                                .padding(.horizontal)
                                .onChange(of: inputText) { _, newValue in
                                    // Save input to UserDefaults
                                    UserDefaults.standard.set(newValue, forKey: selectedTool.storageKey)
                                    processInput()
                                }
                        }
                        .frame(height: geometry.size.height / 2)
                        .background(Color.customSecondaryBackground)
                        
                        Divider()
                        
                        // Output
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Output")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            ScrollView {
                                Text(outputText)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .padding()
                            }
                            .background(Color.customBackground)
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                        .frame(height: geometry.size.height / 2)
                        .background(Color.customSecondaryBackground)
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Copied!", isPresented: $showCopiedAlert) {
            Button("OK") { }
        } message: {
            Text("Output copied to clipboard")
        }
        .onAppear {
            // Load saved input from UserDefaults
            inputText = UserDefaults.standard.string(forKey: selectedTool.storageKey) ?? ""
            processInput()
        }
    }
    
    // MARK: - Actions
    func onClickClear() {
        inputText = ""
        outputText = ""
        jsonNodes = []
        UserDefaults.standard.removeObject(forKey: selectedTool.storageKey)
    }
    
    func onClickCopy() {
#if os(iOS)
        UIPasteboard.general.string = outputText
#elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
#endif
        showCopiedAlert = true
    }
    
    func processInput() {
        guard !inputText.isEmpty else {
            outputText = ""
            jsonNodes = []
            return
        }
        
        switch selectedTool {
        case .jsonFormatter:
            formatJSON()
        case .urlEncodeDecode:
            processURL()
        case .base64:
            processBase64()
        case .jwt:
            decodeJWT()
        case .textCase:
            processTextCase()
        case .hash:
            generateHash()
        }
    }
    
    // MARK: - JSON Formatter
    func formatJSON() {
        do {
            guard let data = inputText.data(using: .utf8) else {
                throw NSError(domain: "Invalid input", code: 0)
            }
            
            let json = try JSONSerialization.jsonObject(with: data)
            let prettyData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            outputText = String(data: prettyData, encoding: .utf8) ?? ""
            
            // Parse for tree view
            jsonNodes = parseJSONToNodes(json: json, key: nil)
        } catch {
            outputText = "Invalid JSON: \(error.localizedDescription)"
            jsonNodes = []
        }
    }
    
    func parseJSONToNodes(json: Any, key: String?) -> [JSONNode] {
        if let dict = json as? [String: Any] {
            let node = JSONNode(key: key, value: dict, type: .dictionary, children: dict.compactMap { k, v in
                parseJSONToNodes(json: v, key: k).first
            })
            return [node]
        } else if let array = json as? [Any] {
            let node = JSONNode(key: key, value: array, type: .array, children: array.enumerated().compactMap { index, item in
                parseJSONToNodes(json: item, key: "[\(index)]").first
            })
            return [node]
        } else if let string = json as? String {
            return [JSONNode(key: key, value: string, type: .string)]
        } else if let number = json as? NSNumber {
            if number.isBool {
                return [JSONNode(key: key, value: number.boolValue, type: .boolean)]
            } else {
                return [JSONNode(key: key, value: number, type: .number)]
            }
        } else if json is NSNull {
            return [JSONNode(key: key, value: "null", type: .null)]
        }
        return []
    }
    
    // MARK: - URL Encode/Decode
    func processURL() {
        if urlProcessMode == .decode {
            // Decode
            if let decoded = inputText.removingPercentEncoding {
                outputText = decoded
            } else {
                outputText = "Failed to decode URL"
            }
        } else {
            // Encode
            if let encoded = inputText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                outputText = encoded
            } else {
                outputText = "Failed to encode URL"
            }
        }
    }
    
    // MARK: - Base64
    func processBase64() {
        if base64ProcessMode == .decode {
            // Decode
            if let data = Data(base64Encoded: inputText),
               let decoded = String(data: data, encoding: .utf8) {
                outputText = decoded
            } else {
                outputText = "Failed to decode Base64"
            }
        } else {
            // Encode
            if let data = inputText.data(using: .utf8) {
                outputText = data.base64EncodedString()
            } else {
                outputText = "Failed to encode Base64"
            }
        }
    }
    
    // MARK: - JWT Decoder
    func decodeJWT() {
        let parts = inputText.split(separator: ".")
        guard parts.count == 3 else {
            outputText = "Invalid JWT format"
            return
        }
        
        var result = "=== JWT Decoded ===\n\n"
        
        // Decode header
        if let header = decodeJWTPart(String(parts[0])) {
            result += "Header:\n\(header)\n\n"
        }
        
        // Decode payload
        if let payload = decodeJWTPart(String(parts[1])) {
            result += "Payload:\n\(payload)\n\n"
        }
        
        result += "Signature:\n\(parts[2])"
        
        outputText = result
    }
    
    func decodeJWTPart(_ part: String) -> String? {
        var base64 = part
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        
        return prettyString
    }
    
    // MARK: - Text Case
    func processTextCase() {
        let lines = [
            "lowercase: \(inputText.lowercased())",
            "UPPERCASE: \(inputText.uppercased())",
            "Title Case: \(inputText.capitalized)",
            "camelCase: \(toCamelCase(inputText))",
            "PascalCase: \(toPascalCase(inputText))",
            "snake_case: \(toSnakeCase(inputText))",
            "kebab-case: \(toKebabCase(inputText))"
        ]
        outputText = lines.joined(separator: "\n\n")
    }
    
    func toCamelCase(_ text: String) -> String {
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        guard !words.isEmpty else { return text }
        return words[0].lowercased() + words.dropFirst().map { $0.capitalized }.joined()
    }
    
    func toPascalCase(_ text: String) -> String {
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        return words.map { $0.capitalized }.joined()
    }
    
    func toSnakeCase(_ text: String) -> String {
        return text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
            .lowercased()
    }
    
    func toKebabCase(_ text: String) -> String {
        return text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .lowercased()
    }
    
    // MARK: - Hash Generator
    func generateHash() {
        guard let data = inputText.data(using: .utf8) else {
            outputText = "Failed to generate hash"
            return
        }
        
        let md5 = data.md5Hash
        let sha1 = data.sha1Hash
        let sha256 = data.sha256Hash
        
        outputText = """
        MD5: \(md5)
        
        SHA-1: \(sha1)
        
        SHA-256: \(sha256)
        """
    }
}

// MARK: - Tree View Component
struct JSONTreeNodeView: View {
    let node: JSONNode
    let level: Int
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                // Indentation
                ForEach(0..<level, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 20)
                }
                
                // Expand/Collapse button
                if !node.children.isEmpty {
                    Button(action: {
//                        withAnimation {
                            isExpanded.toggle()
//                        }
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 16)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16)
                }
                
                // Key
                if let key = node.key {
                    Text(key)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                    Text(":")
                        .foregroundColor(.secondary)
                }
                
                // Type
                Text(node.type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(node.type.color.opacity(0.2))
                    .foregroundColor(node.type.color)
                    .cornerRadius(4)
                
                // Value (for primitives)
                if node.children.isEmpty {
                    Text(String(describing: node.value))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Count (for collections)
                if !node.children.isEmpty {
                    Text("(\(node.children.count) items)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 2)
            
            // Children
            if isExpanded && !node.children.isEmpty {
                ForEach(node.children) { child in
                    JSONTreeNodeView(node: child, level: level + 1)
                }
            }
        }
//        .animation(.default, value: isExpanded)
    }
}

// MARK: - Extensions
extension NSNumber {
    var isBool: Bool {
        CFBooleanGetTypeID() == CFGetTypeID(self)
    }
}

extension Data {
    var md5Hash: String {
        let digest = Insecure.MD5.hash(data: self)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    var sha1Hash: String {
        let digest = Insecure.SHA1.hash(data: self)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    var sha256Hash: String {
        let digest = SHA256.hash(data: self)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    var sha512Hash: String {
        let digest = SHA512.hash(data: self)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - Color Extension for Cross-Platform
extension Color {
    static var customBackground: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #elseif os(macOS)
        return Color(.textBackgroundColor)
        #endif
    }
    
    static var customSecondaryBackground: Color {
        #if os(iOS)
        return Color(.secondarySystemBackground)
        #elseif os(macOS)
        return Color(.windowBackgroundColor)
        #endif
    }
    
    static var customToolbarBackground: Color {
        #if os(iOS)
        return Color(.systemGray6)
        #elseif os(macOS)
        return Color(.controlBackgroundColor)
        #endif
    }
    
    static var customGroupedBackground: Color {
        #if os(iOS)
        return Color(.systemGroupedBackground)
        #elseif os(macOS)
        return Color(.underPageBackgroundColor)
        #endif
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
