import Foundation

extension DailyTaskGroupStorage {
    func uniqueProjects(in projects: [TaskProject]) -> [TaskProject] {
        var seenIDs = Set<TaskProject.ID>()
        return projects.filter { project in
            seenIDs.insert(project.id).inserted
        }
    }

    func uniqueRecentlyDeletedProjects(
        in projects: [RecentlyDeletedProject]
    ) -> [RecentlyDeletedProject] {
        var seenIDs = Set<TaskProject.ID>()
        return projects.filter { project in
            seenIDs.insert(project.project.id).inserted
        }
    }
}
