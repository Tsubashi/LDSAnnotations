//
// Copyright (c) 2016 Hilton Campbell
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import UIKit
import LDSAnnotations

private let cellIdentifier = "cellIdentifier"

class AnnotationViewController: UITableViewController {
    let annotation: Annotation
    let annotationStore: AnnotationStore
    
    enum Section: Int {
        case note
        case bookmark
        case highlights
        case tags
        case links
        case notebooks
        case count
    }
    
    init(annotation: Annotation, annotationStore: AnnotationStore) {
        self.annotation = annotation
        self.annotationStore = annotationStore
        
        super.init(style: .grouped)
        
        title = "Annotation"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44
    }
}

// MARK: - UITableViewDataSource
extension AnnotationViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count.rawValue
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        
        switch section {
        case .note:
            return annotationStore.noteWithAnnotationID(annotation.id) != nil ? 1 : 0
        case .bookmark:
            return annotationStore.bookmarkWithAnnotationID(annotation.id) != nil ? 1 : 0
        case .highlights:
            return annotationStore.highlightsWithAnnotationID(annotation.id).count
        case .tags:
            return annotationStore.tagsWithAnnotationID(annotation.id).count
        case .links:
            return annotationStore.linksWithAnnotationID(annotation.id).count
        case .notebooks:
            return annotationStore.notebooksWithAnnotationID(annotation.id).count
        case .count:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        cell.textLabel?.numberOfLines = 0
        
        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }
        
        switch section {
        case .note:
            if let note = annotationStore.noteWithAnnotationID(annotation.id) {
                cell.textLabel?.text = note.title ?? note.content
            }
        case .bookmark:
            if let bookmark = annotationStore.bookmarkWithAnnotationID(annotation.id) {
                cell.textLabel?.text = bookmark.name
            }
        case .highlights:
            for (index, highlight) in annotationStore.highlightsWithAnnotationID(annotation.id).enumerated() where index == indexPath.row {
                let style = highlight.style == .underline ? "Underline" : "Highlight"
                cell.textLabel?.text = "paragraph AID: \(highlight.paragraphRange.paragraphAID)\noffset start: \(highlight.paragraphRange.startWordOffset)\noffset end: \(highlight.paragraphRange.endWordOffset)\ncolor: \(highlight.highlightColor)\nstyle: \(style)"
            }
        case .tags:
            for (index, tag) in annotationStore.tagsWithAnnotationID(annotation.id).enumerated() where index == indexPath.row {
                cell.textLabel?.text = tag.name
            }
        case .links:
            for (index, link) in annotationStore.linksWithAnnotationID(annotation.id).enumerated() where index == indexPath.row {
                cell.textLabel?.text = link.name
            }
        case .notebooks:
            for (index, notebook) in annotationStore.notebooksWithAnnotationID(annotation.id).enumerated() where index == indexPath.row {
                cell.textLabel?.text = notebook.name
            }
        case .count:
            break
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        
        switch section {
        case .note:
            return "Note"
        case .bookmark:
            return "Bookmark"
        case .highlights:
            return "Highlights"
        case .tags:
            return "Tags"
        case .links:
            return "Links"
        case .notebooks:
            return "Notebooks"
        case .count:
            return nil
        }
    }
}
