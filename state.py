#!/usr/bin/env python

import re

re_state = re.compile('^([A-Z_]+):$')
re_trans = re.compile('^\s+([A-Z_]+)\s*->\s*([A-Z_]+)(\s+[(]([A-Z_]+)[)])?\s*$')

trans = []
# INIT_NOANCHOR:
#        INPUT_NONE -> OPEN_WAIT_FOR_OPEN_NOANCHOR (PKT_OPEN)
# becomes
#  [INIT_NOANCHOR, OPEN_WAIT_FOR_OPEN_NOANCHOR, INPUT_NONE, PKT_OPEN]

base_state = None
for l in open("STATES").readlines():
    m = re_state.match(l)
    if m:
        base_state = m.group(1)
        continue
    m = re_trans.match(l)
    if m:
        inp, new_st, out = m.group(1), m.group(2), m.group(4)
        trans.append((base_state, new_st, inp, out))
        continue
    print "ERROR: could not parse %s" % (l,)

states = set()
for t in trans:
    states.add(t[0])
    states.add(t[1])

start = sorted(s for s in states if "INIT" in s or "NORMAL" in s)

unusual = "BITCOIN_ANCHOR_OTHERSPEND BITCOIN_ANCHOR_OURCOMMIT_DELAYPASSED BITCOIN_ANCHOR_THEIRSPEND BITCOIN_ANCHOR_TIMEOUT BITCOIN_ANCHOR_UNSPENT PKT_ERROR PKT_CLOSE CMD_CLOSE".split()

class Subgraph:
    def __init__(self):
        self.count = 0;

    def start(self, start_trans, trans, do_nop=False, do_unusual=False):
        self.seen = []
        self.nonsink = set()
        self.count += 1

        self.out(start_trans, first=True)

        cur = 1
        while cur < len(self.seen):
            st = self.seen[cur]
            if st not in start:
                for t in trans:
                    if t[0] == t[1] and not do_nop: continue
                    if t[2] in unusual and not do_unusual: continue
                    if st == t[0]:
                        self.out(t)
            cur += 1

        for o in self.seen:
            if o in self.nonsink: continue
            print " %s_%d [color=coral, style=filled];" % (o,self.count)

    def out(self, t, first=False):
        ext = "_O" if first else ""
        lbl = "<%s" % (t[2],)
        if len(t) == 4 and t[3] is not None:
            lbl += "\\n>%s" % (t[3],)

        i = "%s_%d%s" % (t[0], self.count, ext)
        o = "%s_%d" % (t[1], self.count)

        if "\\n" in i:
            i = "_%d%s" % (self.count, ext)

        self.nonsink.add(t[0]+ext)

        if t[0]+ext not in self.seen:
            self.seen.append(t[0]+ext)
            print " %s [label=\"%s\"];" % (i, t[0])
        if t[1] not in self.seen:
            self.seen.append(t[1])
            print " %s [label=\"%s\"];" % (o, t[1])

        print "   %s -> %s [label=\"%s\"];" % (i, o, lbl)


sg = Subgraph()

cluster_cnt = 0

print "digraph lightning {"
print " rankdir=LR;"

for u in unusual:
    res = {}
    for start_trans in trans:
        if start_trans[2] != u: continue
        pkt = None if len(start_trans) == 3 else start_trans[3]
        k = start_trans[1], pkt
        if k not in res: res[k] = []
        res[k].append(start_trans[0])

    if not res: continue

    cluster_cnt+=1
    print " subgraph cluster_%d {" % (cluster_cnt)
    print "   label = \"error path %s\"" % (u,)
    print "   rankdir=TB;"

    for s, p in sorted(res.keys()):
        start_trans = ["\\n".join(sorted(res[s,p])), s, u]
        if p is not None: start_trans.append(p)
        sg.start(start_trans, trans)

    print " }"

for s in start:
    cluster_cnt += 1
    print " subgraph cluster_%d {" % (cluster_cnt)
    print "   label = \"%s\"" % (s,)
    for start_trans in trans:
        if start_trans[0] != s: continue
        if start_trans[2] in unusual: continue
        sg.start(start_trans, trans)
    print " }"

print "}"

