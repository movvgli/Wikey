import Foundation
import Testing
@testable import WikeyCore

struct WorkflowDependencyGraphTests {
    @Test func rejectsSelfReference() {
        let workflow = Workflow()

        #expect(
            WorkflowDependencyGraph.wouldCreateCycle(
                from: workflow.id,
                to: workflow.id,
                in: [workflow]
            )
        )
    }

    @Test func rejectsIndirectCycle() {
        var first = Workflow(name: "첫 번째")
        var second = Workflow(name: "두 번째")
        let third = Workflow(name: "세 번째")
        first.actions = [.runWorkflow(workflowID: second.id)]
        second.actions = [.runWorkflow(workflowID: third.id)]

        #expect(
            WorkflowDependencyGraph.wouldCreateCycle(
                from: third.id,
                to: first.id,
                in: [first, second, third]
            )
        )
        #expect(
            !WorkflowDependencyGraph.wouldCreateCycle(
                from: first.id,
                to: third.id,
                in: [first, second, third]
            )
        )
    }
}
