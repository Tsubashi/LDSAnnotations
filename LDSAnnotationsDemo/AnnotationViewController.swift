//
//  AnnotationViewController.swift
//  LDSAnnotationsDemo
//
//  Created by Stephan Heilner on 3/25/16.
//  Copyright © 2016 Hilton Campbell. All rights reserved.
//

import UIKit
import LDSAnnotations

class AnnotationViewController: UITableViewController {

    let annotation: Annotation
    let annotationStore: AnnotationStore
    private let cellIdentifier = "cellIdentifier"
    
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

        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return Section.Count.rawValue
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section), annotationID = annotation.id else { return 0 }
        
        switch section {
        case .Note:
            return annotation.noteID != nil ? 1 : 0
        case .Bookmark:
            return annotation.bookmarkID != nil ? 1 : 0
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
            if let noteID = annotation.noteID, note = annotationStore.noteWithID(noteID) {
                cell.textLabel?.text = note.title ?? note.content
            }
        case .Bookmark:
            if let bookmarkID = annotation.bookmarkID, bookmark = annotationStore.bookmarkWithID(bookmarkID) {
                cell.textLabel?.text = bookmark.name
            }
        case .Highlights:
            for (index, highlight) in annotationStore.highlightsWithAnnotationID(annotationID).enumerate() where index == indexPath.row {
                let style = highlight.style == .Underline ? "Underline" : "Highlight"
                cell.textLabel?.text = "paragraph AID: \(highlight.paragraphAID)\noffset start: \(highlight.offsetStart)\noffset end: \(highlight.offsetEnd)\ncolor: \(highlight.colorName)\nstyle: \(style)"
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
