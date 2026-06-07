import Foundation

struct ResolvedContact {
    let id: UUID?
    let name: String?
}

/// Resolves the LLM-detected contact name against the App Group contact list.
/// Creates a new contact if none exists with that name, switches `currentContactID`.
/// Returns nil id/name for group chats and unknown senders.
func resolveContact(from result: ReplyResult) -> ResolvedContact {
    let isGroupOrUnknown = result.contactName == nil
        || result.contactName == "Unknown"
        || result.contactName?.isEmpty == true
        || result.contactName?.hasPrefix("Group:") == true

    if isGroupOrUnknown {
        let name = result.contactName?.hasPrefix("Group:") == true ? result.contactName : nil
        return ResolvedContact(id: nil, name: name)
    }

    if let existingID = AppGroupService.shared.currentContactID,
       let existingContact = AppGroupService.shared.loadContacts()
           .first(where: { $0.id == existingID }),
       let llmName = result.contactName,
       normalizeContactName(existingContact.displayName) == normalizeContactName(llmName) {
        return ResolvedContact(id: existingID, name: existingContact.displayName)
    }

    if let name = result.contactName {
        let contact = AppGroupService.shared.findContacts(named: name).first
            ?? AppGroupService.shared.createContact(displayName: name)
        AppGroupService.shared.currentContactID = contact.id
        return ResolvedContact(id: contact.id, name: contact.displayName)
    }

    return ResolvedContact(id: nil, name: nil)
}
