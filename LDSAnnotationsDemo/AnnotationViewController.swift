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
        case Note
        case Bookmark
        case Highlights
        case Tags
        case Links
        case Notebooks
        case Count
    }
    
    init(annotation: Annotation, annotationStore: AnnotationStore) {
        self.annotation = annotation
        self.annotationStore = annotationStore
        
        super.init(style: .Grouped)
        
        title = "Annotation"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44
    }
}

// MARK: - UITableViewDataSource
extension AnnotationViewController {
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return Section.Count.rawValue
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section), annotationID = annotation.id else { return 0 }
        
        switch section {
        case .Note:
            return annotationStore.noteWithAnnotationID(annotationID) != nil ? 1 : 0
        case .Bookmark:
            return annotationStore.bookmarkWithAnnotationID(annotationID) != nil ? 1 : 0
        case .Highlights:
            return annotationStore.highlightsWithAnnotationID(annotationID).count
        case .Tags:
            return annotationStore.tagsWithAnnotationID(annotationID).count
        case .Links:
            return annotationStore.linksWithAnnotationID(annotationID).count
        case .Notebooks:
            return annotationStore.notebooksWithAnnotationID(annotationID).count
        case .Count:
            return 0
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath)
        cell.textLabel?.numberOfLines = 0
        
        guard let section = Section(rawValue: indexPath.section), annotationID = annotation.id else { return UITableViewCell() }
        
        switch section {
        case .Note:
            if let note = annotationStore.noteWithAnnotationID(annotationID) {
                cell.textLabel?.text = note.title ?? note.content
            }
        case .Bookmark:
            if let bookmark = annotationStore.bookmarkWithAnnotationID(annotationID) {
                cell.textLabel?.text = bookmark.name
            }
        case .Highlights:
            for (index, highlight) in annotationStore.highlightsWithAnnotationID(annotationID).enumerate() where index == indexPath.row {
                let style = highlight.style == .Underline ? "Underline" : "Highlight"
                cell.textLabel?.text = "paragraph AID: \(highlight.paragraphRange.paragraphAID)\noffset start: \(highlight.paragraphRange.startWordOffset)\noffset end: \(highlight.paragraphRange.endWordOffset)\ncolor: \(highlight.colorName)\nstyle: \(style)"
            }
        case .Tags:
            for (index, tag) in annotationStore.tagsWithAnnotationID(annotationID).enumerate() where index == indexPath.row {
                cell.textLabel?.text = tag.name
            }
        case .Links:
            for (index, link) in annotationStore.linksWithAnnotationID(annotationID).enumerate() where index == indexPath.row {
                cell.textLabel?.text = link.name
            }
        case .Notebooks:
            for (index, notebook) in annotationStore.notebooksWithAnnotationID(annotationID).enumerate() where index == indexPath.row {
                cell.textLabel?.text = notebook.name
            }
        case .Count:
            break
        }

        return cell
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        
        switch section {
        case .Note:
            return "Note"
        case .Bookmark:
            return "Bookmark"
        case .Highlights:
            return "Highlights"
        case .Tags:
            return "Tags"
        case .Links:
            return "Links"
        case .Notebooks:
            return "Notebooks"
        case .Count:
            return nil
        }
    }
}
