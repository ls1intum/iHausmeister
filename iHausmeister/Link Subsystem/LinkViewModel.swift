//
//  LinkViewModel.swift
//  iHausmeister
//
//  Created by Benjamin Schmitz on 07.04.24.
//

import Foundation

/// ViewModel containing all relevant links.
@Observable public class LinkViewModel {
    /// The links in the ``LinkEntry`` format.
    let links: [LinkEntry] = [
        LinkEntry(name: "Artemis", url: "https://artemis.cit.tum.de"),
        LinkEntry(name: "JIRA", url: "https://jira.ase.in.tum.de"),
        LinkEntry(name: "Confluence", url: "https://confluence.ase.in.tum.de"),
        LinkEntry(name: "Bitbucket", url: "https://bitbucket.ase.in.tum.de"),
        LinkEntry(name: "Bamboo", url: "https://bamboo.ase.in.tum.de"),
        LinkEntry(name: "Status", url: "https://status.ase.in.tum.de"),
        LinkEntry(name: "Grafana", url: "https://grafana.gchq.ase.in.tum.de"),
        LinkEntry(name: "Website", url: "https://ase.cit.tum.de"),
        LinkEntry(name: "Github", url: "https://github.com/ls1intum")
    ]
}
