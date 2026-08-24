import AppKit
import QuickLookUI
import UniformTypeIdentifiers

enum TransferMode { case copy, move }

private enum ConflictDecision { case merge, replace, keepBoth, skip, cancel }

private final class ConflictSession {
    var folderDecisionForAll: ConflictDecision?
    var fileDecisionForAll: ConflictDecision?
    var cancelled = false
}

final class FileItem: NSObject {
    let url: URL
    let isDirectory: Bool
    let size: Int64?
    let modified: Date?

    init(url: URL) {
        self.url = url
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
        isDirectory = values?.isDirectory ?? false
        size = values?.fileSize.map(Int64.init)
        modified = values?.contentModificationDate
    }
}

final class PaneController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate, QLPreviewPanelDataSource {
    weak var partner: PaneController?
    private let volumePopup = NSPopUpButton()
    private let backButton = NSButton(title: "‹", target: nil, action: nil)
    private let forwardButton = NSButton(title: "›", target: nil, action: nil)
    private let upButton = NSButton(title: "↑", target: nil, action: nil)
    private let pathField = NSTextField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private var history: [URL] = []
    private var historyIndex = -1
    private(set) var currentURL: URL
    private var items: [FileItem] = []
    private var draggedURLs: [URL] = []
    private var previewURLs: [URL] = []
    private var contextMenuURLs: [URL] = []
    private let defaultsKey: String

    init(initialURL: URL, defaultsKey: String) {
        currentURL = initialURL
        self.defaultsKey = defaultsKey
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView()
        setupUI()
        refreshVolumes()
        navigate(to: currentURL)
    }

    private func setupUI() {
        backButton.target = self; backButton.action = #selector(goBack)
        forwardButton.target = self; forwardButton.action = #selector(goForward)
        upButton.target = self; upButton.action = #selector(goUp)
        for button in [backButton, forwardButton, upButton] {
            button.bezelStyle = .texturedRounded
            button.font = .systemFont(ofSize: 17, weight: .medium)
            button.widthAnchor.constraint(equalToConstant: 34).isActive = true
        }
        volumePopup.target = self; volumePopup.action = #selector(volumeChanged)
        volumePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 130).isActive = true
        pathField.target = self; pathField.action = #selector(pathEntered)
        pathField.placeholderString = "Path"
        pathField.lineBreakMode = .byTruncatingMiddle

        let toolbar = NSStackView(views: [volumePopup, backButton, forwardButton, upButton, pathField])
        toolbar.orientation = .horizontal; toolbar.spacing = 6

        addColumn("Name", title: "Name", width: 300)
        addColumn("Size", title: "Size", width: 90)
        addColumn("Modified", title: "Modified", width: 145)
        tableView.delegate = self; tableView.dataSource = self
        tableView.headerView = NSTableHeaderView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.doubleAction = #selector(openSelection)
        tableView.target = self
        tableView.registerForDraggedTypes([.fileURL])
        tableView.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        let menu = NSMenu(); menu.delegate = self; tableView.menu = menu

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 11)
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.isHidden = true
        let stack = NSStackView(views: [toolbar, scrollView, progressIndicator, statusLabel])
        stack.orientation = .vertical; stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
            toolbar.heightAnchor.constraint(equalToConstant: 30),
            progressIndicator.heightAnchor.constraint(equalToConstant: 8),
            statusLabel.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    private func addColumn(_ id: String, title: String, width: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
        column.title = title; column.width = width; column.minWidth = id == "Name" ? 140 : 70
        tableView.addTableColumn(column)
    }

    private func refreshVolumes() {
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey], options: [.skipHiddenVolumes]) ?? [URL(fileURLWithPath: "/")]
        volumePopup.removeAllItems()
        for volume in volumes {
            let name = (try? volume.resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? volume.lastPathComponent
            volumePopup.addItem(withTitle: name.isEmpty ? "/" : name)
            volumePopup.lastItem?.representedObject = volume
        }
        if let index = volumes.firstIndex(where: { currentURL.path.hasPrefix($0.path) }) { volumePopup.selectItem(at: index) }
    }

    func navigate(to url: URL, recordHistory: Bool = true) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            showError("Folder not available", detail: url.path); return
        }
        currentURL = url.standardizedFileURL
        UserDefaults.standard.set(currentURL.path, forKey: defaultsKey)
        if recordHistory {
            if historyIndex + 1 < history.count { history.removeSubrange((historyIndex + 1)..<history.count) }
            if history.last != currentURL { history.append(currentURL) }
            historyIndex = history.count - 1
        }
        reload()
    }

    func reload() {
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: currentURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey], options: [])
            items = urls.map(FileItem.init).sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
            }
            pathField.stringValue = currentURL.path
            tableView.reloadData()
            statusLabel.stringValue = "\(items.count) items"
            updateNavigationButtons()
        } catch { showError("Couldn’t open folder", detail: error.localizedDescription) }
    }

    private func updateNavigationButtons() {
        backButton.isEnabled = historyIndex > 0
        forwardButton.isEnabled = historyIndex >= 0 && historyIndex < history.count - 1
        upButton.isEnabled = currentURL.path != "/"
    }

    @objc private func volumeChanged() {
        if let url = volumePopup.selectedItem?.representedObject as? URL { navigate(to: url) }
    }
    @objc private func pathEntered() { navigate(to: URL(fileURLWithPath: pathField.stringValue)) }
    @objc private func goBack() { if historyIndex > 0 { historyIndex -= 1; navigate(to: history[historyIndex], recordHistory: false) } }
    @objc private func goForward() { if historyIndex + 1 < history.count { historyIndex += 1; navigate(to: history[historyIndex], recordHistory: false) } }
    @objc private func goUp() { navigate(to: currentURL.deletingLastPathComponent()) }

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < items.count, let tableColumn else { return nil }
        let item = items[row]
        let cell = NSTableCellView()
        let text = NSTextField(labelWithString: "")
        text.lineBreakMode = .byTruncatingMiddle; text.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(text)
        if tableColumn.identifier.rawValue == "Name" {
            let icon = NSImageView(image: NSWorkspace.shared.icon(forFile: item.url.path))
            icon.imageScaling = .scaleProportionallyDown; icon.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(icon)
            text.stringValue = item.url.lastPathComponent
            NSLayoutConstraint.activate([icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 3), icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor), icon.widthAnchor.constraint(equalToConstant: 18), icon.heightAnchor.constraint(equalToConstant: 18), text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 5), text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -3), text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
        } else {
            text.stringValue = tableColumn.identifier.rawValue == "Size" ? (item.isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: item.size ?? 0, countStyle: .file)) : Self.dateFormatter.string(from: item.modified ?? .distantPast)
            text.textColor = .secondaryLabelColor
            NSLayoutConstraint.activate([text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4), text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4), text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
        }
        return cell
    }

    private static let dateFormatter: DateFormatter = { let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short; return f }()

    func tableViewSelectionDidChange(_ notification: Notification) {
        let count = tableView.selectedRowIndexes.count
        statusLabel.stringValue = count == 0 ? "\(items.count) items" : "\(count) selected"
    }

    @objc private func openSelection() {
        guard let item = selectedItems.first else { return }
        if item.isDirectory { navigate(to: item.url) } else { NSWorkspace.shared.open(item.url) }
    }

    private var selectedItems: [FileItem] { tableView.selectedRowIndexes.compactMap { $0 < items.count ? items[$0] : nil } }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let url = items[row].url
        if !draggedURLs.contains(url) { draggedURLs = tableView.selectedRowIndexes.map { items[$0].url } }
        return url as NSURL
    }

    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) { draggedURLs = [] }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        tableView.setDropRow(-1, dropOperation: .on)
        return info.draggingSourceOperationMask.contains(.move) && NSEvent.modifierFlags.contains(.command) ? .move : .copy
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else { return false }
        let mode: TransferMode = NSEvent.modifierFlags.contains(.command) ? .move : .copy
        transfer(urls, to: currentURL, mode: mode)
        return true
    }

    func transfer(_ urls: [URL], to destination: URL, mode: TransferMode) {
        guard !urls.isEmpty else { return }
        setTransferUI(active: true, value: 0, maximum: 1, text: "Calculating size…")
        partner?.setTransferUI(active: true, value: 0, maximum: 1, text: "Calculating size…")
        view.layoutSubtreeIfNeeded()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var errors: [String] = []
            let totalBytes = max(1, urls.reduce(Int64(0)) { $0 + self.byteSize(of: $1) })
            var completedBytes: Int64 = 0
            var lastReported: Int64 = 0
            let conflictSession = ConflictSession()

            let report: (Int64, String) -> Void = { added, name in
                completedBytes += added
                if completedBytes - lastReported >= 1_048_576 || completedBytes >= totalBytes {
                    lastReported = completedBytes
                    let done = completedBytes
                    DispatchQueue.main.async {
                        let text = "\(mode == .copy ? "Copying" : "Moving") \(name) — \(ByteCountFormatter.string(fromByteCount: done, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))"
                        self.setTransferUI(active: true, value: Double(done), maximum: Double(totalBytes), text: text)
                        self.partner?.setTransferUI(active: true, value: Double(done), maximum: Double(totalBytes), text: text)
                    }
                }
            }

            for (index, source) in urls.enumerated() {
                if conflictSession.cancelled { break }
                DispatchQueue.main.async {
                    let text = "\(mode == .copy ? "Copying" : "Moving") item \(index + 1) of \(urls.count): \(source.lastPathComponent)"
                    self.statusLabel.stringValue = text; self.partner?.statusLabel.stringValue = text
                }
                let target = destination.appendingPathComponent(source.lastPathComponent)
                do {
                    _ = try self.transferRecursively(from: source, to: target, mode: mode,
                                                     conflicts: conflictSession, progress: report)
                } catch { errors.append("\(source.lastPathComponent): \(error.localizedDescription)") }
            }
            DispatchQueue.main.async {
                self.setTransferUI(active: false, value: 0, maximum: 1, text: "")
                self.partner?.setTransferUI(active: false, value: 0, maximum: 1, text: "")
                self.reload(); self.partner?.reload()
                if !errors.isEmpty { self.showError("Some items could not be transferred", detail: errors.joined(separator: "\n")) }
            }
        }
    }

    private func setTransferUI(active: Bool, value: Double, maximum: Double, text: String) {
        tableView.isEnabled = !active
        progressIndicator.maxValue = maximum
        progressIndicator.doubleValue = min(value, maximum)
        progressIndicator.isHidden = !active
        if active { statusLabel.stringValue = text }
    }

    private func byteSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .fileSizeKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        if values.isRegularFile == true { return Int64(values.fileSize ?? 0) }
        guard values.isDirectory == true,
              let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [.skipsPackageDescendants]) else { return 0 }
        var total: Int64 = 0
        for case let child as URL in enumerator {
            if let childValues = try? child.resourceValues(forKeys: keys), childValues.isRegularFile == true {
                total += Int64(childValues.fileSize ?? 0)
            }
        }
        return total
    }

    @discardableResult
    private func transferRecursively(from source: URL, to originalTarget: URL, mode: TransferMode,
                                     conflicts: ConflictSession,
                                     progress: (Int64, String) -> Void) throws -> Bool {
        if conflicts.cancelled { return false }
        let values = try source.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        var target = originalTarget
        let sourceIsDirectory = values.isDirectory == true && values.isSymbolicLink != true

        if FileManager.default.fileExists(atPath: target.path) {
            var destinationIsDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: target.path, isDirectory: &destinationIsDirectory)
            let canMerge = sourceIsDirectory && destinationIsDirectory.boolValue
            let decision = conflictDecision(for: source, destination: target, canMerge: canMerge, session: conflicts)
            switch decision {
            case .merge where canMerge:
                break
            case .replace:
                try FileManager.default.removeItem(at: target)
            case .keepBoth:
                target = uniqueDestination(for: source, in: target.deletingLastPathComponent())
            case .skip:
                progress(byteSize(of: source), source.lastPathComponent)
                return false
            case .cancel:
                conflicts.cancelled = true
                return false
            case .merge:
                return false
            }
        }

        if values.isSymbolicLink == true {
            try FileManager.default.copyItem(at: source, to: target)
            if mode == .move { try FileManager.default.removeItem(at: source) }
            return true
        }
        if sourceIsDirectory {
            if !FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
            }
            var completed = true
            for child in try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
                let childCompleted = try transferRecursively(from: child,
                    to: target.appendingPathComponent(child.lastPathComponent), mode: mode,
                    conflicts: conflicts, progress: progress)
                completed = completed && childCompleted
                if conflicts.cancelled { completed = false; break }
            }
            if let attributes = try? FileManager.default.attributesOfItem(atPath: source.path) {
                try? FileManager.default.setAttributes(attributes, ofItemAtPath: target.path)
            }
            if mode == .move && completed {
                try FileManager.default.removeItem(at: source)
            }
            return completed
        }

        FileManager.default.createFile(atPath: target.path, contents: nil)
        let reader = try FileHandle(forReadingFrom: source)
        let writer = try FileHandle(forWritingTo: target)
        defer { try? reader.close(); try? writer.close() }
        while true {
            let data = try reader.read(upToCount: 1_048_576) ?? Data()
            if data.isEmpty { break }
            try writer.write(contentsOf: data)
            progress(Int64(data.count), source.lastPathComponent)
        }
        if let attributes = try? FileManager.default.attributesOfItem(atPath: source.path) {
            try? FileManager.default.setAttributes(attributes, ofItemAtPath: target.path)
        }
        if mode == .move { try FileManager.default.removeItem(at: source) }
        return true
    }

    private func conflictDecision(for source: URL, destination: URL, canMerge: Bool,
                                  session: ConflictSession) -> ConflictDecision {
        if let saved = canMerge ? session.folderDecisionForAll : session.fileDecisionForAll { return saved }

        var result: (ConflictDecision, Bool) = (.cancel, false)
        DispatchQueue.main.sync {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = canMerge ? "A folder with this name already exists" : "An item with this name already exists"
            alert.informativeText = conflictDescription(source: source, destination: destination)
            if canMerge { alert.addButton(withTitle: "Merge Folders") }
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Keep Both")
            alert.addButton(withTitle: "Skip")
            alert.addButton(withTitle: "Cancel Transfer")

            let applyToAll = NSButton(checkboxWithTitle: "Apply this choice to all remaining \(canMerge ? "folder" : "file") conflicts", target: nil, action: nil)
            alert.accessoryView = applyToAll
            let response = alert.runModal()
            let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            let decisions: [ConflictDecision] = canMerge
                ? [.merge, .replace, .keepBoth, .skip, .cancel]
                : [.replace, .keepBoth, .skip, .cancel]
            let decision = decisions.indices.contains(index) ? decisions[index] : .cancel
            result = (decision, applyToAll.state == .on && decision != .cancel)
        }
        if result.1 {
            if canMerge { session.folderDecisionForAll = result.0 }
            else { session.fileDecisionForAll = result.0 }
        }
        return result.0
    }

    private func conflictDescription(source: URL, destination: URL) -> String {
        func details(_ url: URL) -> String {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            let kind = values?.isDirectory == true ? "Folder" : ByteCountFormatter.string(fromByteCount: Int64(values?.fileSize ?? 0), countStyle: .file)
            let modified = values?.contentModificationDate.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .short) } ?? "Unknown date"
            return "\(kind), modified \(modified)"
        }
        return "Source: \(source.lastPathComponent) — \(details(source))\nDestination: \(destination.lastPathComponent) — \(details(destination))"
    }

    private func uniqueDestination(for source: URL, in folder: URL) -> URL {
        var target = folder.appendingPathComponent(source.lastPathComponent)
        guard FileManager.default.fileExists(atPath: target.path) else { return target }
        let ext = source.pathExtension
        let base = source.deletingPathExtension().lastPathComponent
        var n = 2
        repeat {
            let name = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            target = folder.appendingPathComponent(name); n += 1
        } while FileManager.default.fileExists(atPath: target.path)
        return target
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let clickedRow = tableView.clickedRow
        if clickedRow >= 0 && !tableView.selectedRowIndexes.contains(clickedRow) {
            tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }
        let selected = selectedItems
        contextMenuURLs = selected.map(\.url)
        add(menu, "Open", #selector(openSelection), enabled: !selected.isEmpty)
        add(menu, "Open With…", #selector(openWith), enabled: selected.count == 1 && !selected[0].isDirectory)
        add(menu, "Quick Look", #selector(quickLookSelection), enabled: !selected.isEmpty)
        menu.addItem(.separator())
        add(menu, "Copy to Other Pane", #selector(copyToOther), enabled: !selected.isEmpty && partner != nil)
        add(menu, "Move to Other Pane", #selector(moveToOther), enabled: !selected.isEmpty && partner != nil)
        add(menu, "Duplicate", #selector(duplicateSelection), enabled: !selected.isEmpty)
        menu.addItem(.separator())
        add(menu, "Rename…", #selector(renameSelection), enabled: selected.count == 1)
        add(menu, "New Folder…", #selector(newFolder))
        add(menu, "Move to Trash", #selector(trashSelection), enabled: !selected.isEmpty)
        menu.addItem(.separator())
        add(menu, "Reveal in Finder", #selector(revealSelection), enabled: !selected.isEmpty)
        add(menu, "Copy Path", #selector(copyPath), enabled: !selected.isEmpty)
        add(menu, "Get Info", #selector(getInfo), enabled: selected.count == 1)
        add(menu, "Refresh", #selector(refreshAction))
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, enabled: Bool = true) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; item.isEnabled = enabled; menu.addItem(item)
    }

    @objc private func copyToOther() { if let partner { partner.transfer(selectedItems.map(\.url), to: partner.currentURL, mode: .copy) } }
    @objc private func moveToOther() { if let partner { partner.transfer(selectedItems.map(\.url), to: partner.currentURL, mode: .move) } }
    @objc private func duplicateSelection() { transfer(selectedItems.map(\.url), to: currentURL, mode: .copy) }
    @objc private func revealSelection() { NSWorkspace.shared.activateFileViewerSelecting(selectedItems.map(\.url)) }
    @objc private func quickLookSelection() {
        let urls = contextMenuURLs.isEmpty ? selectedItems.map(\.url) : contextMenuURLs
        guard !urls.isEmpty else { return }
        previewURLs = urls
        contextMenuURLs = []
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.currentPreviewItemIndex = 0
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { previewURLs.count }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        guard previewURLs.indices.contains(index) else { return nil }
        return previewURLs[index] as NSURL
    }
    @objc private func copyPath() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(selectedItems.map { $0.url.path }.joined(separator: "\n"), forType: .string) }
    @objc private func refreshAction() { reload() }
    @objc private func getInfo() { if let url = selectedItems.first?.url { NSWorkspace.shared.activateFileViewerSelecting([url]) } }

    @objc private func openWith() {
        guard let url = selectedItems.first?.url else { return }
        let panel = NSOpenPanel(); panel.title = "Choose an application"; panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.allowedContentTypes = [.application]; panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        if panel.runModal() == .OK, let app = panel.url { NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()) }
    }

    @objc private func renameSelection() {
        guard let item = selectedItems.first, let name = prompt(title: "Rename", message: "New name:", value: item.url.lastPathComponent) else { return }
        do { try FileManager.default.moveItem(at: item.url, to: item.url.deletingLastPathComponent().appendingPathComponent(name)); reload() }
        catch { showError("Couldn’t rename item", detail: error.localizedDescription) }
    }

    @objc private func newFolder() {
        guard let name = prompt(title: "New Folder", message: "Folder name:", value: "Untitled Folder") else { return }
        do { try FileManager.default.createDirectory(at: currentURL.appendingPathComponent(name), withIntermediateDirectories: false); reload() }
        catch { showError("Couldn’t create folder", detail: error.localizedDescription) }
    }

    @objc private func trashSelection() {
        let names = selectedItems.map { $0.url.lastPathComponent }.joined(separator: ", ")
        let alert = NSAlert(); alert.messageText = "Move to Trash?"; alert.informativeText = names; alert.addButton(withTitle: "Move to Trash"); alert.addButton(withTitle: "Cancel"); alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        for item in selectedItems { try? FileManager.default.trashItem(at: item.url, resultingItemURL: nil) }
        reload()
    }

    private func prompt(title: String, message: String, value: String) -> String? {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = message; alert.addButton(withTitle: "OK"); alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: value); field.frame = NSRect(x: 0, y: 0, width: 300, height: 24); alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty, !field.stringValue.contains("/") else { return nil }
        return field.stringValue
    }

    private func showError(_ title: String, detail: String) { let alert = NSAlert(); alert.messageText = title; alert.informativeText = detail; alert.alertStyle = .warning; alert.runModal() }
}

final class MainViewController: NSViewController {
    override func loadView() {
        view = NSView()
        let home = FileManager.default.homeDirectoryForCurrentUser
        let left = PaneController(initialURL: Self.savedFolder(forKey: "leftPanePath", fallback: home), defaultsKey: "leftPanePath")
        let right = PaneController(initialURL: Self.savedFolder(forKey: "rightPanePath", fallback: home), defaultsKey: "rightPanePath")
        left.partner = right; right.partner = left
        addChild(left); addChild(right)
        let split = NSSplitView(); split.isVertical = true; split.dividerStyle = .thin; split.autosaveName = "CMQMainSplit"; split.translatesAutoresizingMaskIntoConstraints = false
        split.addArrangedSubview(left.view); split.addArrangedSubview(right.view)
        view.addSubview(split)
        NSLayoutConstraint.activate([split.leadingAnchor.constraint(equalTo: view.leadingAnchor), split.trailingAnchor.constraint(equalTo: view.trailingAnchor), split.topAnchor.constraint(equalTo: view.topAnchor), split.bottomAnchor.constraint(equalTo: view.bottomAnchor), left.view.widthAnchor.constraint(greaterThanOrEqualToConstant: 360), right.view.widthAnchor.constraint(greaterThanOrEqualToConstant: 360)])
    }

    private static func savedFolder(forKey key: String, fallback: URL) -> URL {
        guard let path = UserDefaults.standard.string(forKey: key) else { return fallback }
        let url = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue ? url : fallback
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 680), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "CMQ"
        window.minSize = NSSize(width: 800, height: 500)
        window.setFrameAutosaveName("CMQMainWindow")
        let restored = window.setFrameUsingName("CMQMainWindow")
        let restoredFrameIsUsable = restored && window.frame.width >= 800 && window.frame.height >= 500
        if !restoredFrameIsUsable {
            window.setContentSize(NSSize(width: 1100, height: 680))
            window.center()
            window.saveFrame(usingName: "CMQMainWindow")
        }
        window.contentViewController = MainViewController(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        mainMenu.addItem(applicationItem)
        let applicationMenu = NSMenu(title: "CMQ")
        let quitItem = NSMenuItem(title: "Quit CMQ", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        applicationMenu.addItem(quitItem)
        mainMenu.setSubmenu(applicationMenu, for: applicationItem)
        NSApp.mainMenu = mainMenu
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
