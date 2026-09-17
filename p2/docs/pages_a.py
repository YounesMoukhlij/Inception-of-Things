# -*- coding: utf-8 -*-
import math
from sketch import *


def page1(c, n, tot):
    header(c, "p2 on one page", "One VM. One node. One IP. Everything the evaluator touches lives behind 192.168.56.110:80", n, tot)

    sketch_box(c, 40, 105, 762, 335, "YOUR LAPTOP   (Ubuntu host)", INK, None, 21, 1.5, 12)

    # --- the host side --------------------------------------------------
    sketch_box(c, 58, 250, 190, 110, "terminal", GREY, FILL_GREY, 31, 1.1, 10)
    txt(c, 68, 322, 'curl -H "Host: app2.com" \\', HAND, 9.5, INK)
    txt(c, 68, 306, '     192.168.56.110', HAND, 9.5, INK)
    txt(c, 68, 282, 'Hello from app2', HAND, 9.5, GREEN)
    check(c, 68, 262, 8, GREEN, 1.8, 44)

    sketch_box(c, 58, 196, 190, 36, None, BLUE, FILL_BLUE, 35, 1.1)
    txt(c, 70, 209, "vboxnet0   192.168.56.1", HAND, 10, BLUE)

    rough_arrow(c, 250, 300, 290, 318, RED, 1.6, 8, 37)

    # --- virtualbox / vm ------------------------------------------------
    sketch_box(c, 270, 118, 512, 300, "VirtualBox 7.2   (needs /dev/vboxdrv)", GREY, None, 41, 1.3, 11)
    sketch_box(c, 286, 130, 482, 258, "VM  ynassibiS  .  ubuntu/jammy64  .  2048 MB  .  1 vCPU", PURPLE, None, 45, 1.4, 10.5)

    sketch_box(c, 294, 336, 170, 24, None, GREY, FILL_GREY, 49, 1.0)
    txt(c, 302, 344, "enp0s3   NAT   ssh :2222", HAND, 9, GREY)
    sketch_box(c, 294, 306, 170, 24, None, RED, FILL_RED, 53, 1.1)
    txt(c, 302, 314, "enp0s8   192.168.56.110", HAND, 9, RED)

    # --- k3s ------------------------------------------------------------
    sketch_box(c, 298, 142, 458, 150, "K3s server  v1.36.4+k3s1     node: ynassibis  [Ready]", GREEN, None, 57, 1.4, 10.5)

    sketch_box(c, 308, 166, 88, 96, None, AMBER, FILL_AMBER, 61, 1.2)
    ctxt(c, 352, 222, "Traefik", HAND, 11, AMBER)
    ctxt(c, 352, 206, ":80", HAND, 11, AMBER)
    ctxt(c, 352, 188, "reads the", HAND, 8, GREY)
    ctxt(c, 352, 178, "Host header", HAND, 8, GREY)

    rows = [("app1", 236, [560], BLUE, FILL_BLUE, "app1.com"),
            ("app2", 194, [530, 570, 610], TEAL, HexColor(0xE3F2F2), "app2.com"),
            ("app3", 152, [560], PURPLE, FILL_PURP, "anything else")]
    for name, ry, cxs, col, fil, host in rows:
        sketch_box(c, 414, ry, 330, 36, None, col, fil, 65 + ry, 1.1)
        txt(c, 422, ry + 21, host, HAND, 9, col)
        txt(c, 422, ry + 9, "-> %s-service" % name, HAND, 8.5, GREY)
        rough_arrow(c, 398, ry + 18, 410, ry + 18, AMBER, 1.3, 6, 70 + ry)
        for i, cx in enumerate(cxs):
            pod_shape(c, cx, ry + 18, 14, None, col, fil, 80 + ry + i)
            ctxt(c, cx, ry + 15, name, HAND, 7.5, col)
        lbl = "1 pod" if len(cxs) == 1 else "%d pods" % len(cxs)
        txt(c, 655, ry + 14, lbl, SCRIPT, 15, col)

    note(c, 46, 86, ["5 pods, 3 services, 1 ingress, 1 node -- and from the outside it is just one IP on port 80."], RED, 16)


def page2(c, n, tot):
    header(c, "Three files build the whole thing", "Vagrantfile makes the box. setup.sh installs the cluster. confs/ describes the apps.", n, tot)

    cards = [
        (46, "Vagrantfile", BLUE, FILL_BLUE,
         ["box = ubuntu/jammy64", "private_network -> .110  (2nd NIC)",
          "synced_folder type: rsync", "provision: scripts/setup.sh", "vb.name = ynassibiS"]),
        (300, "scripts/setup.sh", AMBER, FILL_AMBER,
         ["find the NIC that owns .110", "install K3s in SERVER mode",
          "wait until the node is Ready", "kubectl apply -f /vagrant/confs/", "copy kubeconfig to vagrant user"]),
        (554, "confs/*.yaml", GREEN, FILL_GREEN,
         ["app1 / app2 / app3", "each = Deployment + Service",
          "ingress.yaml routes by Host", "pure desired state -", "no scripting, no order"]),
    ]
    for x, title, col, fil, lines in cards:
        w = 248 if x == 554 else 240
        sketch_box(c, x, 330, w, 122, title, col, fil, int(x), 1.4, 13)
        y = 418
        for ln in lines:
            txt(c, x + 12, y, "-  " + ln, HAND, 9.5, INK)
            y -= 15

    # --- the vagrant up pipeline ----------------------------------------
    txt(c, 46, 296, "what `vagrant up` actually does, in order:", SCRIPT, 18, INK)
    steps = [("1", "download", "the box"), ("2", "create VM", "+ 2 NICs"), ("3", "boot", "+ ssh key"),
             ("4", "rsync p2/", "-> /vagrant"), ("5", "run", "setup.sh"), ("6", "install", "K3s server"),
             ("7", "apply", "confs/")]
    bw, gap = 95, 15
    for i, (num, l1, l2) in enumerate(steps):
        x = 46 + i * (bw + gap)
        col = AMBER if i >= 3 else GREY
        fil = FILL_AMBER if i >= 3 else FILL_GREY
        sketch_box(c, x, 205, bw, 56, None, col, fil, 200 + i * 7, 1.2)
        ctxt(c, x + bw / 2, 243, num, SCRIPT, 17, col)
        ctxt(c, x + bw / 2, 228, l1, HAND, 9, INK)
        ctxt(c, x + bw / 2, 215, l2, HAND, 9, INK)
        if i:
            rough_arrow(c, x - gap + 1, 233, x - 3, 233, INK, 1.3, 6, 260 + i)

    rough_curve_arrow(c, 735, 200, 428, 200, 40, PURPLE, 1.4, 7, 301)
    ctxt(c, 582, 150, "`vagrant provision` re-runs only steps 4 - 7", SCRIPT, 18, PURPLE)

    sketch_box(c, 46, 62, 366, 72, None, RED, FILL_RED, 311, 1.2)
    txt(c, 58, 116, "so setup.sh must be idempotent", HAND, 11, RED)
    wrap(c, 58, 102, "It is re-run whole, every time. The K3s installer and kubectl apply are both safe to repeat; the .bashrc line is guarded with grep -q.",
         342, HAND, 9.2, 12.5, INK)

    sketch_box(c, 432, 62, 370, 72, None, BLUE, FILL_BLUE, 321, 1.2)
    txt(c, 444, 116, "rsync is a copy, not a live mount", HAND, 11, BLUE)
    wrap(c, 444, 102, "Editing confs/ on the host changes nothing inside the VM until the next rsync. ubuntu/jammy64 ships no Guest Additions, so vboxsf cannot mount at all.",
         346, HAND, 9.2, 12.5, INK)


def page3(c, n, tot):
    header(c, "Why SERVER mode?", "A Kubernetes cluster needs a brain. With exactly one VM, that VM has to be the brain.", n, tot)

    # --- server panel ----------------------------------------------------
    sketch_box(c, 46, 235, 376, 215, "k3s server        <- what we run", GREEN, FILL_GREEN, 401, 1.5, 12.5)
    parts = ["API server", "Scheduler", "Controller mgr", "SQLite (not etcd)",
             "CoreDNS", "Traefik", "ServiceLB", "Flannel", "kubelet", "containerd"]
    for i, p in enumerate(parts):
        cx = 58 + (i % 2) * 182
        cy = 390 - (i // 2) * 31
        sketch_box(c, cx, cy, 172, 25, None, GREEN, HexColor(0xD9EFE3), 405 + i, 1.0)
        ctxt(c, cx + 86, cy + 8, p, HAND, 9.5, INK)
    txt(c, 58, 247, "control plane + worker, both in one node", HAND, 9, GREY)

    # --- agent panel -----------------------------------------------------
    sketch_box(c, 440, 235, 362, 215, "k3s agent        <- what we do NOT run", GREY, FILL_GREY, 431, 1.5, 12.5)
    for i, p in enumerate(["kubelet", "containerd", "flannel"]):
        sketch_box(c, 456, 390 - i * 31, 150, 25, None, GREY, HexColor(0xE4E6E9), 435 + i, 1.0)
        ctxt(c, 531, 398 - i * 31, p, HAND, 9.5, GREY)
    cross(c, 640, 355, 46, RED, 3.0, 441)
    wrap(c, 456, 290, "An agent has no API server and no datastore. It exists only to join a server that already runs. With a single VM there is nothing to join -- so an agent alone can never form a cluster.",
         330, HAND, 9.8, 13.5, INK)

    # --- the flag string, annotated --------------------------------------
    cmd = "server  --node-ip=192.168.56.110  --flannel-iface=enp0s8  --write-kubeconfig-mode=644"
    fs = 11.5
    cw = sw(cmd, HAND, fs)
    cx0 = (W - cw) / 2
    sketch_box(c, cx0 - 16, 168, cw + 32, 32, None, INK, HexColor(0xF3F1EA), 451, 1.2)
    txt(c, cx0, 178, cmd, HAND, fs, INK)

    ann = [(46, 250, "--node-ip", BLUE,
            "pins the node's InternalIP to .110. Without it Kubernetes picks the NAT address and the evaluator's curl finds nothing."),
           (310, 250, "--flannel-iface", TEAL,
            "the pod network must ride the private NIC. setup.sh resolves it at runtime (enp0s8 here) -- never hardcode eth1."),
           (574, 228, "--write-kubeconfig-mode", PURPLE,
            "makes /etc/rancher/k3s/k3s.yaml world-readable so the vagrant user runs kubectl without sudo.")]
    for x, wd, frag, col, body in ann:
        pre = cmd.split(frag)[0]
        fx = cx0 + sw(pre, HAND, fs) + sw(frag, HAND, fs) / 2
        rough_curve_arrow(c, fx, 166, x + wd / 2, 134, 14, col, 1.2, 6, 461 + x)
        txt(c, x, 118, frag, HAND, 10.5, col)
        wrap(c, x, 104, body, wd, HAND, 9.2, 12.5, INK)


def page4(c, n, tot):
    header(c, "Why an Ingress, not three NodePorts?", "The subject asks for app1.com and app2.com on one address. Only an Ingress can do that.", n, tot)

    # --- without ----------------------------------------------------------
    sketch_box(c, 46, 168, 370, 282, "WITHOUT an Ingress", GREY, FILL_GREY, 501, 1.5, 13)
    ctxt(c, 231, 412, "three services, three random ports", HAND, 9.5, GREY)
    for i, (p, a) in enumerate([("30001", "app1"), ("30002", "app2"), ("30003", "app3")]):
        y = 350 - i * 46
        sketch_box(c, 70, y, 120, 34, None, GREY, HexColor(0xE4E6E9), 505 + i, 1.1)
        ctxt(c, 130, y + 11, ":" + p, HAND, 11, INK)
        rough_arrow(c, 194, y + 17, 240, y + 17, GREY, 1.2, 6, 509 + i)
        sketch_box(c, 244, y, 100, 34, None, GREY, HexColor(0xE4E6E9), 512 + i, 1.1)
        ctxt(c, 294, y + 11, a, HAND, 11, INK)
    for i, t in enumerate(["no host names at all", "evaluator must know 3 ports", "does not match the subject"]):
        cross(c, 72, 186 + i * 19, 9, RED, 1.8, 520 + i)
        txt(c, 90, 186 + i * 19, t, HAND, 9.5, INK)

    # --- with -------------------------------------------------------------
    sketch_box(c, 440, 168, 362, 282, "WITH an Ingress", GREEN, FILL_GREEN, 531, 1.5, 13)
    ctxt(c, 621, 412, "one port, routed by the Host header", HAND, 9.5, GREEN)
    sketch_box(c, 460, 330, 110, 54, None, AMBER, FILL_AMBER, 535, 1.2)
    ctxt(c, 515, 362, "Traefik", HAND, 11, AMBER)
    ctxt(c, 515, 346, ":80", HAND, 11, AMBER)
    ctxt(c, 515, 336, "one door", HAND, 8, GREY)
    for i, (h, a, col) in enumerate([("app1.com", "app1", BLUE), ("app2.com", "app2", TEAL), ("(no host)", "app3", PURPLE)]):
        y = 372 - i * 40
        rough_arrow(c, 574, 357, 606, y + 12, col, 1.2, 6, 540 + i)
        sketch_box(c, 610, y, 172, 26, None, col, HexColor(0xEFF4FA), 545 + i, 1.1)
        txt(c, 618, y + 8, "%s  ->  %s" % (h, a), HAND, 9.5, col)
    for i, t in enumerate(["exactly what the subject asks", "one IP, one port, three names", "app3 is the default catch-all"]):
        check(c, 462, 186 + i * 19, 9, GREEN, 1.8, 550 + i)
        txt(c, 480, 186 + i * 19, t, HAND, 9.5, INK)

    # --- the rule table ----------------------------------------------------
    sketch_box(c, 46, 62, 756, 82, None, INK, None, 561, 1.3)
    txt(c, 58, 122, "ingress.yaml -- read it top to bottom:", HAND, 11, INK)
    cols = [(60, 'host: app1.com', 'app1-service:80', BLUE),
            (310, 'host: app2.com', 'app2-service:80', TEAL),
            (560, '(no host: field)', 'app3-service:80', PURPLE)]
    for x, rule, target, col in cols:
        txt(c, x, 100, rule, HAND, 10, col)
        rough_arrow(c, x + 2, 88, x + 26, 88, col, 1.2, 5, 570 + x)
        txt(c, x + 32, 84, target, HAND, 10, INK)
        txt(c, x, 70, "matched on the HTTP Host header" if col is not PURPLE else "the 'otherwise' case in the subject",
            HAND, 8.5, GREY)
