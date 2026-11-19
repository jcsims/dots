-- Ported from Ghostty: cmd+left/right switch tabs
rex.bind("cmd+left", "client.tab.previous")
rex.bind("cmd+right", "client.tab.next")

-- Since I use vertical tabs, it sometimes makes more sense to use up/down to
-- traverse tabs.
rex.bind("cmd+up", "client.tab.previous")
rex.bind("cmd+down", "client.tab.next")
