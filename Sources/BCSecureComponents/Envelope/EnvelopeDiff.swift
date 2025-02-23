import Foundation
import WolfBase

extension Envelope {
    public func diff(target: Envelope) -> Envelope {
        Self.diff(source: self, target: target)
    }

    public static func diff(source: Envelope, target: Envelope) -> Envelope {
        guard source != target else {
            return "noChange"
        }

        func diffAssertions(sourceAssertions: [Envelope], targetAssertions: [Envelope]) -> Envelope {
            let sourceAssertions = Set(sourceAssertions)
            let targetAssertions = Set(targetAssertions)
            
            // Assertions that are common to both the source and target will not appear in the diff.
            let commonAssertions = sourceAssertions.intersection(targetAssertions)
            
            // Find the assertions that are unique to the source or the target
            let uniqueSourceAssertions = sourceAssertions.subtracting(commonAssertions)
            let uniqueTargetAssertions = targetAssertions.subtracting(commonAssertions)
           
            // For each unique source assertion, find the smallest edit that transforms it into
            // one of the unique target assertions.
            var assertionEdits: Set<Envelope> = []
            var remainingSourceAssertions = uniqueSourceAssertions
            var remainingTargetAssertions = uniqueTargetAssertions
            for sourceAssertion in uniqueSourceAssertions.sorted() {
                guard !remainingTargetAssertions.isEmpty else {
                    break
                }
                var bestDiff: Envelope!
                var bestElementCount: Int = .max
                var selectedTargetAssertion: Envelope!
                for targetAssertion in remainingTargetAssertions.sorted() {
                    var diff = diff(source: sourceAssertion, target: targetAssertion)
                    if diff.subject != "edit" {
                        diff = Envelope("edit", sourceAssertion.digest)
                            .addAssertion("assertion", diff)
                    }
                    let count = diff.elementsCount
                    if count < bestElementCount {
                        bestDiff = diff
                        bestElementCount = count
                        selectedTargetAssertion = targetAssertion
                    }
                }
                assertionEdits.insert(bestDiff)
                remainingSourceAssertions.remove(sourceAssertion)
                remainingTargetAssertions.remove(selectedTargetAssertion)
            }
            
            // diffAssertions transform existing assertions in the source
            // remainingSourceAssertions are to be deleted in the source
            for assertionToBeDeleted in remainingSourceAssertions {
                assertionEdits.insert(Envelope("delete", Envelope(assertionToBeDeleted.digest)))
            }
            // remainingTargetAssertions are to be added to the source
            for assertionToBeAdded in remainingTargetAssertions {
                assertionEdits.insert(Envelope("add", assertionToBeAdded))
            }
            
            let diffSubject = diff(source: source.subject, target: target.subject)
            return assertionEdits.reduce(into: diffSubject) {
                $0 = try! $0.addAssertion($1)
            }
        }
        
//        func diffAssertion(source: Envelope, target: Envelope) -> Envelope {
//            var result = Envelope("edit", source.digest)
//            switch source {
//            case .node(subject: <#T##Envelope#>, assertions: <#T##[Envelope]#>, digest: <#T##Digest#>)
//            }
//            return result
//        }
        
        switch source {
        case .node(_, let sourceAssertions, _):
            switch target {
            case .node(_, let targetAssertions, _):
                return diffAssertions(sourceAssertions: sourceAssertions, targetAssertions: targetAssertions)
            default:
                return diffAssertions(sourceAssertions: sourceAssertions, targetAssertions: [])
            }
        case .assertion(let sourceAssertion):
            var result = Envelope("edit", sourceAssertion.digest)
            switch target {
            case .assertion(let targetAssertion):
                let predicateEdit = diff(source: sourceAssertion.predicate, target: targetAssertion.predicate)
                let objectEdit = diff(source: sourceAssertion.object, target: targetAssertion.object)
                
                if predicateEdit != "noChange" {
                    result = result.addAssertion("predicate", predicateEdit)
                }
                
                if objectEdit != "noChange" {
                    result = result.addAssertion("object", objectEdit)
                }
            case .encrypted, .elided:
                result = result.addAssertion("assertion", target)
            default:
                todo()
            }
            return result
        case .wrapped(let sourceEnvelope, _):
            switch target {
            case .node(_, let targetAssertions, _):
                return diffAssertions(sourceAssertions: [], targetAssertions: targetAssertions)
            case .wrapped(let targetEnvelope, _):
                return diff(source: sourceEnvelope, target: targetEnvelope).wrap()
            default:
                return target
            }
        default:
            return target
        }
    }
    
    public func applyDiff(_ diff: Envelope) throws -> Envelope {
        try Self.applyDiff(source: self, diff: diff)
    }
    
    public static func applyDiff(source: Envelope, diff: Envelope) throws -> Envelope {
        var result = source
        if diff.subject != "noChange" {
            result = result.replaceSubject(with: diff.subject)
        }
        for assertion in diff.assertions {
            guard let assertionPredicate = assertion.subject.predicate else {
                throw EnvelopeError.invalidDiff
            }
            switch assertionPredicate {
            case "add":
                result = try result.addAssertion(assertion.object)
            case "delete":
                let target = try assertion.object!.extractSubject(Digest.self)
                result = result.removeAssertion(target)
            case "edit":
                let target = try assertion.subject.object.extractSubject(Digest.self)
                let sourceAssertion = try source.assertion(withDigest: target)
                if let assertionEdit = try? assertion.assertion(withPredicate: "assertion").object {
                    let assertion = try applyDiff(source: sourceAssertion, diff: assertionEdit)
                    result = try result.replaceAssertion(sourceAssertion, with: assertion)
                } else {
                    var predicate = sourceAssertion.predicate!
                    var object = sourceAssertion.object!
                    if let predicateEdit = try? assertion.assertion(withPredicate: "predicate").object {
                        predicate = try applyDiff(source: predicate, diff: predicateEdit)
                    }
                    if let objectEdit = try? assertion.assertion(withPredicate: "object").object {
                        object = try applyDiff(source: object, diff: objectEdit)
                    }
                    result = try result.replaceAssertion(sourceAssertion, with: Envelope(predicate, object))
                }
            default:
                throw EnvelopeError.invalidDiff
            }
        }
        return result
    }
}

/*
 source:
 "alice"
 
 target:
 "bob"
 
 [replaceSubject "bob"]
*/
