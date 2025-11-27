/*
 * Copyright (C) 2011-2020 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

/*
 * Base utility types for the AST.
 *
 * Valid methods for Node:
 *
 * node.children -> Returns an array of immediate children.
 *
 * node.descendants -> Returns an array of all strict descendants (children
 *     and children of children, transitively).
 *
 * node.flatten -> Returns an array containing the strict descendants and
 *     the node itself.
 *
 * node.filter(type) -> Returns an array containing those elements in
 *     node.flatten that are of the given type.
 *
 * node.mapChildren{...} -> Returns a new node with all children
 *     replaced according to the given closure.
 *
 * Examples:
 *
 * node.filter(Setting.self).unique -> Returns all of the settings that the AST's
 *     IfThenElse blocks depend on.
 *
 * node.filter(StructOffset.self).unique -> Returns all of the structure offsets
 *     that the AST depends on.
 */

@MainActor
class Node: Hashable {
    let codeOrigin: CodeOrigin
    
    init(codeOrigin: CodeOrigin) {
        self.codeOrigin = codeOrigin
    }
    
    var codeOriginString: String {
        return codeOrigin.description
    }
    
    var children: [Node] {
        return []
    }
    
    var descendants: [Node] {
        return children.flatMap { $0.flatten }
    }
    
    var flatten: [Node] {
        return [self] + descendants
    }
    
    func filter<T: Node>(_ type: T.Type) -> [T] {
        return flatten.compactMap { $0 as? T }
    }
    
    func mapChildren(_ transform: (Node) -> Node) -> Node {
        return self
    }
    
    // Add dump property to base Node class
    var dump: String {
        return "Node"
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    static func == (lhs: Node, rhs: Node) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

class NoChildren: Node {
    override init(codeOrigin: CodeOrigin) {
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return []
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        return self
    }
}

struct StructOffsetKey: Hashable {
    let structName: String
    let field: String
    
    init(structName: String, field: String) {
        self.structName = structName
        self.field = field
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(structName)
        hasher.combine(field)
    }
    
    static func == (lhs: StructOffsetKey, rhs: StructOffsetKey) -> Bool {
        return lhs.structName == rhs.structName && lhs.field == rhs.field
    }
}

/*
 * AST nodes.
 */

@MainActor
class StructOffset: NoChildren {
    let structName: String
    let field: String
    
    private static var mapping: [StructOffsetKey: StructOffset] = [:]
    
    init(codeOrigin: CodeOrigin, structName: String, field: String) {
        self.structName = structName
        self.field = field
        super.init(codeOrigin: codeOrigin)
    }
    
    static func forField(codeOrigin: CodeOrigin, structName: String, field: String) -> StructOffset {
        let key = StructOffsetKey(structName: structName, field: field)
        
        if mapping[key] == nil {
            mapping[key] = StructOffset(codeOrigin: codeOrigin, structName: structName, field: field)
        }
        return mapping[key]!
    }
    
    override var dump: String {
        return "\(structName)::\(field)"
    }
    
    func compare(to other: StructOffset) -> ComparisonResult {
        if structName != other.structName {
            return structName.compare(other.structName)
        }
        return field.compare(other.field)
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return true }
    var isRegister: Bool { return false }
}

@MainActor
class Sizeof: NoChildren {
    let structName: String
    
    private static var mapping: [String: Sizeof] = [:]
    
    init(codeOrigin: CodeOrigin, structName: String) {
        self.structName = structName
        super.init(codeOrigin: codeOrigin)
    }
    
    static func forName(codeOrigin: CodeOrigin, structName: String) -> Sizeof {
        if mapping[structName] == nil {
            mapping[structName] = Sizeof(codeOrigin: codeOrigin, structName: structName)
        }
        return mapping[structName]!
    }
    
    override var dump: String {
        return "sizeof \(structName)"
    }
    
    func compare(to other: Sizeof) -> ComparisonResult {
        return structName.compare(other.structName)
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return true }
    var isRegister: Bool { return false }
}

class Immediate: NoChildren {
    let value: Int
    
    init(codeOrigin: CodeOrigin, value: Int) {
        self.value = value
        super.init(codeOrigin: codeOrigin)
    }
    
    override var dump: String {
        return "\(value)"
    }
    
    var name: String {
        return String(format: "0x%x", value)
    }
    
    static func == (lhs: Immediate, rhs: Immediate) -> Bool {
        return lhs.value == rhs.value
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return true }
    var isImmediateOperand: Bool { return true }
    var isRegister: Bool { return false }
}

class AddImmediates: Node {
    let left: Node
    let right: Node
    
    init(codeOrigin: CodeOrigin, left: Node, right: Node) {
        self.left = left
        self.right = right
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return [left, right]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        return AddImmediates(codeOrigin: codeOrigin, left: transform(left), right: transform(right))
    }
    
    override var dump: String {
        return "(\(left.dump) + \(right.dump))"
    }
    
    var value: String {
        return "\(left.dump) + \(right.dump)"
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return true }
    var isImmediateOperand: Bool { return true }
    var isRegister: Bool { return false }
}

class SubImmediates: Node {
    let left: Node
    let right: Node
    
    init(codeOrigin: CodeOrigin, left: Node, right: Node) {
        self.left = left
        self.right = right
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return [left, right]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        return SubImmediates(codeOrigin: codeOrigin, left: transform(left), right: transform(right))
    }
    
    override var dump: String {
        return "(\(left.dump) - \(right.dump))"
    }
    
    var value: String {
        return "\(left.dump) - \(right.dump)"
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return true }
    var isImmediateOperand: Bool { return true }
    var isRegister: Bool { return false }
}

class MulImmediates: Node {
    let left: Node
    let right: Node
    
    init(codeOrigin: CodeOrigin, left: Node, right: Node) {
        self.left = left
        self.right = right
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return [left, right]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        return MulImmediates(codeOrigin: codeOrigin, left: transform(left), right: transform(right))
    }
    
    override var dump: String {
        return "(\(left.dump) * \(right.dump))"
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return true }
    var isImmediateOperand: Bool { return false }
    var isRegister: Bool { return false }
}

class NegImmediate: Node {
    let child: Node
    
    init(codeOrigin: CodeOrigin, child: Node) {
        self.child = child
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return [child]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        return NegImmediate(codeOrigin: codeOrigin, child: transform(child))
    }
    
    override var dump: String {
        return "(-\(child.dump))"
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return true }
    var isImmediateOperand: Bool { return false }
    var isRegister: Bool { return false }
}

class OrImmediates: Node {
    let left: Node
    let right: Node
    
    init(codeOrigin: CodeOrigin, left: Node, right: Node) {
        self.left = left
        self.right = right
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return [left, right]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        return OrImmediates(codeOrigin: codeOrigin, left: transform(left), right: transform(right))
    }
    
    override var dump: String {
        return "(\(left.dump) | \(right.dump))"
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return true }
    var isImmediateOperand: Bool { return false }
    var isRegister: Bool { return false }
}

class AndImmediates: Node {
    let left: Node
    let right: Node
    
    init(codeOrigin: CodeOrigin, left: Node, right: Node) {
        self.left = left
        self.right = right
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return [left, right]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        return AndImmediates(codeOrigin: codeOrigin, left: transform(left), right: transform(right))
    }
    
    override var dump: String {
        return "(\(left.dump) & \(right.dump))"
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return true }
    var isImmediateOperand: Bool { return false }
    var isRegister: Bool { return false }
}

class XorImmediates: Node {
    let left: Node
    let right: Node
    
    init(codeOrigin: CodeOrigin, left: Node, right: Node) {
        self.left = left
        self.right = right
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return [left, right]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        return XorImmediates(codeOrigin: codeOrigin, left: transform(left), right: transform(right))
    }
    
    override var dump: String {
        return "(\(left.dump) ^ \(right.dump))"
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return true }
    var isImmediateOperand: Bool { return false }
    var isRegister: Bool { return false }
}

class BitnotImmediate: Node {
    let child: Node
    
    init(codeOrigin: CodeOrigin, child: Node) {
        self.child = child
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return [child]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        return BitnotImmediate(codeOrigin: codeOrigin, child: transform(child))
    }
    
    override var dump: String {
        return "(~\(child.dump))"
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return true }
    var isImmediateOperand: Bool { return false }
    var isRegister: Bool { return false }
}

class StringLiteral: NoChildren {
    let value: String
    
    init(codeOrigin: CodeOrigin, value: String) {
        // Remove quotes from string literal
        let startIndex = value.index(value.startIndex, offsetBy: 1)
        let endIndex = value.index(value.endIndex, offsetBy: -1)
        self.value = String(value[startIndex..<endIndex])
        super.init(codeOrigin: codeOrigin)
    }
    
    override var dump: String {
        return value
    }
    
    static func == (lhs: StringLiteral, rhs: StringLiteral) -> Bool {
        return lhs.value == rhs.value
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return false }
    var isImmediateOperand: Bool { return false }
    var isRegister: Bool { return false }
}

@MainActor
class RegisterID: NoChildren {
    let name: String
    
    private static var mapping: [String: RegisterID] = [:]
    
    init(codeOrigin: CodeOrigin, name: String) {
        self.name = name
        super.init(codeOrigin: codeOrigin)
    }
    
    static func forName(codeOrigin: CodeOrigin, name: String) -> RegisterID {
        if mapping[name] == nil {
            mapping[name] = RegisterID(codeOrigin: codeOrigin, name: name)
        }
        return mapping[name]!
    }
    
    override var dump: String {
        return name
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return false }
    var isRegister: Bool { return true }
}

@MainActor
class FPRegisterID: NoChildren {
    let name: String
    
    private static var mapping: [String: FPRegisterID] = [:]
    
    init(codeOrigin: CodeOrigin, name: String) {
        self.name = name
        super.init(codeOrigin: codeOrigin)
    }
    
    static func forName(codeOrigin: CodeOrigin, name: String) -> FPRegisterID {
        if mapping[name] == nil {
            mapping[name] = FPRegisterID(codeOrigin: codeOrigin, name: name)
        }
        return mapping[name]!
    }
    
    override var dump: String {
        return name
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return false }
    var isImmediateOperand: Bool { return false }
    var isRegister: Bool { return true }
}

@MainActor
class VecRegisterID: NoChildren {
    let name: String
    
    private static var mapping: [String: VecRegisterID] = [:]
    
    init(codeOrigin: CodeOrigin, name: String) {
        self.name = name
        super.init(codeOrigin: codeOrigin)
    }
    
    static func forName(codeOrigin: CodeOrigin, name: String) -> VecRegisterID {
        if mapping[name] == nil {
            mapping[name] = VecRegisterID(codeOrigin: codeOrigin, name: name)
        }
        return mapping[name]!
    }
    
    override var dump: String {
        return name
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return false }
    var isImmediateOperand: Bool { return false }
    var isRegister: Bool { return true }
}

class SpecialRegister: NoChildren {
    let name: String
    
    init(name: String) {
        self.name = name
        super.init(codeOrigin: CodeOrigin.none)
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return false }
    var isImmediateOperand: Bool { return false }
    var isRegister: Bool { return true }
}

@MainActor
class Variable: NoChildren {
    let name: String
    let originalName: String?
    
    private static var mapping: [String: Variable] = [:]
    
    init(codeOrigin: CodeOrigin, name: String, originalName: String? = nil) {
        self.name = name
        self.originalName = originalName
        super.init(codeOrigin: codeOrigin)
    }
    
    static func forName(codeOrigin: CodeOrigin, name: String, originalName: String? = nil) -> Variable {
        if mapping[name] == nil {
            mapping[name] = Variable(codeOrigin: codeOrigin, name: name, originalName: originalName)
        }
        return mapping[name]!
    }
    
    var originalNameValue: String {
        return originalName ?? name
    }
    
    override var dump: String {
        return originalNameValue
    }
    
    var description: String {
        return "<variable \(originalNameValue) at \(codeOriginString)>"
    }
}

class Address: Node {
    let base: Node
    let offset: Node
    
    init(codeOrigin: CodeOrigin, base: Node, offset: Node) {
        self.base = base
        self.offset = offset
        super.init(codeOrigin: codeOrigin)
        
        // Validation
        guard base is Variable || (base as? RegisterID)?.isRegister == true else {
            fatalError("Bad base for address \(base) at \(codeOriginString)")
        }
        guard offset is Variable || (offset as? Immediate)?.isImmediate == true else {
            fatalError("Bad offset for address \(offset) at \(codeOriginString)")
        }
    }
    
    func withOffset(extraOffset: Int) -> Address {
        let newOffset = Immediate(codeOrigin: codeOrigin, value: (offset as! Immediate).value + extraOffset)
        return Address(codeOrigin: codeOrigin, base: base, offset: newOffset)
    }
    
    override var children: [Node] {
        return [base, offset]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        return Address(codeOrigin: codeOrigin, base: transform(base), offset: transform(offset))
    }
    
    override var dump: String {
        return "\(offset.dump)[\(base.dump)]"
    }
    
    var isAddress: Bool { return true }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return false }
    var isImmediateOperand: Bool { return true }
    var isRegister: Bool { return false }
}

class BaseIndex: Node {
    let base: Node
    let index: Node
    let scale: Node
    let offset: Node
    
    init(codeOrigin: CodeOrigin, base: Node, index: Node, scale: Node, offset: Node) {
        self.base = base
        self.index = index
        self.scale = scale
        self.offset = offset
        super.init(codeOrigin: codeOrigin)
    }
    
    var scaleValue: Int {
        let scaleInt = (scale as! Immediate).value
        guard [1, 2, 4, 8].contains(scaleInt) else {
            fatalError("Bad scale: \(scaleInt) at \(codeOriginString)")
        }
        return scaleInt
    }
    
    var scaleShift: Int {
        switch scaleValue {
        case 1: return 0
        case 2: return 1
        case 4: return 2
        case 8: return 3
        default: fatalError("Bad scale: \(scaleValue) at \(codeOriginString)")
        }
    }
    
    func withOffset(extraOffset: Int) -> BaseIndex {
        let newOffset = Immediate(codeOrigin: codeOrigin, value: (offset as! Immediate).value + extraOffset)
        return BaseIndex(codeOrigin: codeOrigin, base: base, index: index, scale: scale, offset: newOffset)
    }
    
    override var children: [Node] {
        return [base, index, offset]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        return BaseIndex(codeOrigin: codeOrigin, base: transform(base), index: transform(index), scale: transform(scale), offset: transform(offset))
    }
    
    override var dump: String {
        return "\(offset.dump)[\(base.dump), \(index.dump), \(scaleValue)]"
    }
    
    var isAddress: Bool { return true }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return false }
    var isImmediateOperand: Bool { return false }
    var isRegister: Bool { return false }
}

class AbsoluteAddress: NoChildren {
    let address: Node
    
    init(codeOrigin: CodeOrigin, address: Node) {
        self.address = address
        super.init(codeOrigin: codeOrigin)
    }
    
    func withOffset(extraOffset: Int) -> AbsoluteAddress {
        let newAddress = Immediate(codeOrigin: codeOrigin, value: (address as! Immediate).value + extraOffset)
        return AbsoluteAddress(codeOrigin: codeOrigin, address: newAddress)
    }
    
    override var dump: String {
        return "\(address.dump)[]"
    }
    
    var isAddress: Bool { return true }
    var isLabel: Bool { return false }
    var isImmediate: Bool { return false }
    var isImmediateOperand: Bool { return true }
    var isRegister: Bool { return false }
}

class Instruction: Node {
    let opcode: String
    let operands: [Node]
    let annotation: String?
    
    init(codeOrigin: CodeOrigin, opcode: String, operands: [Node], annotation: String? = nil) {
        self.opcode = opcode
        self.operands = operands
        self.annotation = annotation
        super.init(codeOrigin: codeOrigin)
    }
    
    func cloneWithNewOperands(_ newOperands: [Node]) -> Instruction {
        return Instruction(codeOrigin: codeOrigin, opcode: opcode, operands: newOperands, annotation: annotation)
    }
    
    override var children: [Node] {
        return operands
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        let newOperands = operands.map(transform)
        return Instruction(codeOrigin: codeOrigin, opcode: opcode, operands: newOperands, annotation: annotation)
    }
    
    override var dump: String {
        let operandsStr = operands.map { $0.dump }.joined(separator: ", ")
        return "\t\(opcode) \(operandsStr)"
    }
    
    func lowerDefault() {
        switch opcode {
        case "localAnnotation":
            // $asm.putLocalAnnotation()
            break
        case "globalAnnotation":
            // $asm.putGlobalAnnotation()
            break
        case "emit":
            var str = ""
            for operand in operands {
                if operand is LocalLabelReference {
                    // str += operand.asmLabel
                } else {
                    str += operand.dump
                }
            }
            // $asm.puts "#{str}"
            break
        case "tagCodePtr", "tagReturnAddress", "untagReturnAddress", "removeCodePtrTag", "untagArrayPtr", "removeArrayPtrTag":
            break
        default:
            fatalError("Unhandled opcode \(opcode) at \(codeOriginString)")
        }
    }
    
    func prepareToLower(backendName: String) {
        // Swift doesn't have dynamic method calling like Ruby, so we'll need to implement this differently
        // For now, just call the default implementation
        recordMetaDataDefault()
    }
    
    func recordMetaDataDefault() {
        // Implementation would depend on the assembler context
        // $asm.codeOrigin(codeOriginString) if $enableCodeOriginComments
        // $asm.annotation(annotation) if $enableInstrAnnotations
        // $asm.debugAnnotation(codeOrigin.debugDirective) if $enableDebugAnnotations
    }
}

class Error: NoChildren {
    override init(codeOrigin: CodeOrigin) {
        super.init(codeOrigin: codeOrigin)
    }
    
    override var dump: String {
        return "\terror"
    }
}

@MainActor
class ConstExpr: NoChildren {
    let value: String
    
    private static var mapping: [String: ConstExpr] = [:]
    
    init(codeOrigin: CodeOrigin, value: String) {
        self.value = value
        super.init(codeOrigin: codeOrigin)
    }
    
    static func forName(codeOrigin: CodeOrigin, text: String) -> ConstExpr {
        if mapping[text] == nil {
            mapping[text] = ConstExpr(codeOrigin: codeOrigin, value: text)
        }
        return mapping[text]!
    }
    
    override var dump: String {
        return "constexpr (\(value))"
    }
    
    func compare(to other: ConstExpr) -> ComparisonResult {
        return value.compare(other.value)
    }
    
    var isImmediate: Bool { return true }
}

class ConstDecl: Node {
    let variable: Variable
    let value: Node
    
    init(codeOrigin: CodeOrigin, variable: Variable, value: Node) {
        self.variable = variable
        self.value = value
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return [variable, value]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        return ConstDecl(codeOrigin: codeOrigin, variable: transform(variable) as! Variable, value: transform(value))
    }
    
    override var dump: String {
        return "const \(variable.dump) = \(value.dump)"
    }
}

// Global variables (equivalent to Ruby globals)
@MainActor
var labelMapping: [String: Any] = [:]
@MainActor
var referencedExternLabels: [Label] = []

@MainActor
class Label: NoChildren {
    let name: String
    let definedInFile: Bool
    var isExtern: Bool
    var isGlobal: Bool
    var isAligned: Bool
    var alignTo: Bool
    var isExport: Bool
    
    init(codeOrigin: CodeOrigin, name: String, definedInFile: Bool = false) {
        self.name = name
        self.definedInFile = definedInFile
        self.isExtern = true
        self.isGlobal = false
        self.isAligned = true
        self.alignTo = false
        self.isExport = false
        super.init(codeOrigin: codeOrigin)
    }
    
    static func forName(codeOrigin: CodeOrigin, name: String, definedInFile: Bool = false) -> Label {
        if let existing = labelMapping[name] as? Label {
            if definedInFile {
                existing.clearExtern()
            }
            return existing
        } else {
            let newLabel = Label(codeOrigin: codeOrigin, name: name, definedInFile: definedInFile)
            labelMapping[name] = newLabel
            if definedInFile {
                newLabel.clearExtern()
            }
            return newLabel
        }
    }
    
    static func setAsGlobal(codeOrigin: CodeOrigin, name: String) {
        if let existing = labelMapping[name] as? Label {
            guard !existing.isGlobal else {
                fatalError("Label: \(name) declared global multiple times")
            }
            existing.setGlobal()
        } else {
            let newLabel = Label(codeOrigin: codeOrigin, name: name)
            newLabel.setGlobal()
            labelMapping[name] = newLabel
        }
    }
    
    static func setAsGlobalExport(codeOrigin: CodeOrigin, name: String) {
        if let existing = labelMapping[name] as? Label {
            guard !existing.isGlobal else {
                fatalError("Label: \(name) declared global multiple times")
            }
            existing.setGlobalExport()
        } else {
            let newLabel = Label(codeOrigin: codeOrigin, name: name)
            newLabel.setGlobalExport()
            labelMapping[name] = newLabel
        }
    }
    
    static func setAsUnalignedGlobal(codeOrigin: CodeOrigin, name: String) {
        if let existing = labelMapping[name] as? Label {
            guard !existing.isGlobal else {
                fatalError("Label: \(name) declared global multiple times")
            }
            existing.setUnalignedGlobal()
        } else {
            let newLabel = Label(codeOrigin: codeOrigin, name: name)
            newLabel.setUnalignedGlobal()
            labelMapping[name] = newLabel
        }
    }
    
    static func setAsAligned(codeOrigin: CodeOrigin, name: String, alignTo: Bool) {
        if let existing = labelMapping[name] as? Label {
            guard !existing.isAligned else {
                fatalError("Label: \(name) declared aligned multiple times")
            }
            existing.setAligned(alignTo: alignTo)
        } else {
            let newLabel = Label(codeOrigin: codeOrigin, name: name)
            newLabel.setAligned(alignTo: alignTo)
            labelMapping[name] = newLabel
        }
    }
    
    static func setAsUnalignedGlobalExport(codeOrigin: CodeOrigin, name: String) {
        if let existing = labelMapping[name] as? Label {
            guard !existing.isGlobal else {
                fatalError("Label: \(name) declared global multiple times")
            }
            existing.setUnalignedGlobalExport()
        } else {
            let newLabel = Label(codeOrigin: codeOrigin, name: name)
            newLabel.setUnalignedGlobalExport()
            labelMapping[name] = newLabel
        }
    }
    
    static func resetReferenced() {
        referencedExternLabels = []
    }
    
    static func forReferencedExtern(_ block: (String) -> Void) {
        for label in referencedExternLabels {
            block(label.name)
        }
    }
    
    func clearExtern() {
        isExtern = false
    }
    
    func setGlobal() {
        isGlobal = true
    }
    
    func setGlobalExport() {
        isGlobal = true
        isExport = true
    }
    
    func setUnalignedGlobal() {
        isGlobal = true
        isAligned = false
    }
    
    func setAligned(alignTo: Bool) {
        isAligned = true
        self.alignTo = alignTo
        // You must use this from cpp for the alignment to work on all linkers
        isGlobal = true
    }
    
    func setUnalignedGlobalExport() {
        isGlobal = true
        isAligned = false
        isExport = true
    }
    
    override var dump: String {
        return "\(name):"
    }
}

@MainActor
class LocalLabel: NoChildren {
    let name: String
    
    private static var uniqueNameCounter = 0
    
    init(codeOrigin: CodeOrigin, name: String) {
        self.name = name
        super.init(codeOrigin: codeOrigin)
    }
    
    static func forName(codeOrigin: CodeOrigin, name: String) -> LocalLabel {
        if let existing = labelMapping[name] as? LocalLabel {
            return existing
        } else {
            guard codeOrigin != CodeOrigin.none else {
                fatalError("nil codeOrigin")
            }
            let newLabel = LocalLabel(codeOrigin: codeOrigin, name: name)
            labelMapping[name] = newLabel
            return newLabel
        }
    }
    
    static func unique(codeOrigin: CodeOrigin, comment: String) -> LocalLabel {
        var newName = "_\(comment)"
        while labelMapping[newName] != nil {
            uniqueNameCounter += 1
            newName = "_\(uniqueNameCounter)_\(comment)"
        }
        return forName(codeOrigin: codeOrigin, name: newName)
    }
    
    var cleanName: String {
        if name.hasPrefix(".") {
            return "_" + String(name.dropFirst())
        } else {
            return name
        }
    }
    
    override var dump: String {
        return "\(name):"
    }
}

class LabelReference: Node {
    let label: Label
    var offset: Int
    
    init(codeOrigin: CodeOrigin, label: Label) {
        self.label = label
        self.offset = 0
        super.init(codeOrigin: codeOrigin)
    }
    
    func plusOffset(additionalOffset: Int) -> LabelReference {
        let result = LabelReference(codeOrigin: codeOrigin, label: label)
        result.offset = offset + additionalOffset
        return result
    }
    
    override var children: [Node] {
        return [label]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        let result = LabelReference(codeOrigin: codeOrigin, label: transform(label) as! Label)
        result.offset = offset
        return result
    }
    
    var name: String {
        return label.name
    }
    
    var isExtern: Bool {
        if let labelObj = labelMapping[name] as? Label {
            return labelObj.isExtern
        }
        return false
    }
    
    func used() {
        if !referencedExternLabels.contains(label) && isExtern {
            referencedExternLabels.append(label)
        }
    }
    
    override var dump: String {
        return label.name
    }
    
    var value: String {
        // return asmLabel()
        return name
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return true }
    var isImmediate: Bool { return false }
    var isImmediateOperand: Bool { return true }
}

class LocalLabelReference: NoChildren {
    let label: LocalLabel
    
    init(codeOrigin: CodeOrigin, label: LocalLabel) {
        self.label = label
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return [label]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        return LocalLabelReference(codeOrigin: codeOrigin, label: transform(label) as! LocalLabel)
    }
    
    var name: String {
        return label.name
    }
    
    override var dump: String {
        return label.name
    }
    
    var value: String {
        // return asmLabel()
        return name
    }
    
    var isAddress: Bool { return false }
    var isLabel: Bool { return true }
    var isImmediate: Bool { return false }
    var isImmediateOperand: Bool { return true }
}

class Sequence: Node {
    let list: [Node]
    
    init(codeOrigin: CodeOrigin, list: [Node]) {
        self.list = list
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return list
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        let newList = list.map(transform)
        return Sequence(codeOrigin: codeOrigin, list: newList)
    }
    
    override var dump: String {
        return list.map { $0.dump }.joined(separator: "\n")
    }
}

@MainActor
class True: NoChildren {
    static let instance = True()
    
    private init() {
        super.init(codeOrigin: CodeOrigin.none)
    }
    
    var value: Bool {
        return true
    }
    
    override var dump: String {
        return "true"
    }
}

@MainActor
class False: NoChildren {
    static let instance = False()
    
    private init() {
        super.init(codeOrigin: CodeOrigin.none)
    }
    
    var value: Bool {
        return false
    }
    
    override var dump: String {
        return "false"
    }
}

// Extensions to provide Ruby-like behavior
extension Bool {
    var asNode: Node {
        return self ? True.instance : False.instance
    }
}

@MainActor
class Setting: NoChildren {
    let name: String
    
    private static var mapping: [String: Setting] = [:]
    
    init(codeOrigin: CodeOrigin, name: String) {
        self.name = name
        super.init(codeOrigin: codeOrigin)
    }
    
    static func forName(codeOrigin: CodeOrigin, name: String) -> Setting {
        if mapping[name] == nil {
            mapping[name] = Setting(codeOrigin: codeOrigin, name: name)
        }
        return mapping[name]!
    }
    
    override var dump: String {
        return name
    }
}

class And: Node {
    let left: Node
    let right: Node
    
    init(codeOrigin: CodeOrigin, left: Node, right: Node) {
        self.left = left
        self.right = right
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return [left, right]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        return And(codeOrigin: codeOrigin, left: transform(left), right: transform(right))
    }
    
    override var dump: String {
        return "(\(left.dump) and \(right.dump))"
    }
}

class Or: Node {
    let left: Node
    let right: Node
    
    init(codeOrigin: CodeOrigin, left: Node, right: Node) {
        self.left = left
        self.right = right
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return [left, right]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        return Or(codeOrigin: codeOrigin, left: transform(left), right: transform(right))
    }
    
    override var dump: String {
        return "(\(left.dump) or \(right.dump))"
    }
}

class Not: Node {
    let child: Node
    
    init(codeOrigin: CodeOrigin, child: Node) {
        self.child = child
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return [child]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        return Not(codeOrigin: codeOrigin, child: transform(child))
    }
    
    override var dump: String {
        return "(not \(child.dump))"
    }
}

class Skip: NoChildren {
    override init(codeOrigin: CodeOrigin) {
        super.init(codeOrigin: codeOrigin)
    }
    
    override var dump: String {
        return "\tskip"
    }
}

class IfThenElse: Node {
    let predicate: Node
    let thenCase: Node
    var elseCase: Node
    
    init(codeOrigin: CodeOrigin, predicate: Node, thenCase: Node) {
        self.predicate = predicate
        self.thenCase = thenCase
        self.elseCase = Skip(codeOrigin: codeOrigin)
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return [predicate, thenCase, elseCase]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        let ifThenElse = IfThenElse(codeOrigin: codeOrigin, predicate: transform(predicate), thenCase: transform(thenCase))
        ifThenElse.elseCase = transform(elseCase)
        return ifThenElse
    }
    
    override var dump: String {
        return "if \(predicate.dump)\n\(thenCase.dump)\nelse\n\(elseCase.dump)\nend"
    }
}

class Macro: Node {
    let name: String
    let variables: [Node]
    let body: Node
    
    init(codeOrigin: CodeOrigin, name: String, variables: [Node], body: Node) {
        self.name = name
        self.variables = variables
        self.body = body
        super.init(codeOrigin: codeOrigin)
    }
    
    override var children: [Node] {
        return variables + [body]
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        let newVariables = variables.map(transform)
        let newBody = transform(body)
        return Macro(codeOrigin: codeOrigin, name: name, variables: newVariables, body: newBody)
    }
    
    override var dump: String {
        let variablesStr = variables.map { $0.dump }.joined(separator: ", ")
        return "macro \(name)(\(variablesStr))\n\(body.dump)\nend"
    }
}

class MacroCall: Node {
    let name: String
    let operands: [Node]
    let annotation: String?
    let originalName: String?
    
    init(codeOrigin: CodeOrigin, name: String, operands: [Node], annotation: String?, originalName: String? = nil) {
        self.name = name
        self.operands = operands
        self.annotation = annotation
        self.originalName = originalName
        super.init(codeOrigin: codeOrigin)
        
        // Validation
        guard operands.count > 0 else {
            fatalError("Operands cannot be empty")
        }
    }
    
    var originalNameValue: String {
        return originalName ?? name
    }
    
    override var children: [Node] {
        return operands
    }
    
    override func mapChildren(_ transform: (Node) -> Node) -> Node {
        let newOperands = operands.map(transform)
        return MacroCall(codeOrigin: codeOrigin, name: name, operands: newOperands, annotation: annotation, originalName: originalName)
    }
    
    var dump: String {
        let operandsStr = operands.map { $0.dump }.joined(separator: ", ")
        return "\t\(originalNameValue)(\(operandsStr))"
    }
}

// Helper class for CodeOrigin (equivalent to Ruby's CodeOrigin)
@MainActor
class CodeOrigin: CustomStringConvertible, Equatable {
    static let none = CodeOrigin(description: "none")
    
    let description: String
    
    init(description: String) {
        self.description = description
    }
    
    var debugDirective: String {
        return description
    }
    
    static func == (lhs: CodeOrigin, rhs: CodeOrigin) -> Bool {
        return lhs.description == rhs.description
    }
}

// Extension to provide unique functionality for arrays
extension Array where Element: Hashable {
    var unique: [Element] {
        return Array(Set(self))
    }
}
