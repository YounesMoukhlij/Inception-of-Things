# -*- coding: utf-8 -*-
import math
from sketch import *


def page5(c, n, tot):
    header(c, "How 'replicas: 3' becomes 3 pods", "You never create a pod. You declare a Deployment, and two controllers do the rest.", n, tot)

    # --- the yaml you wrote -------------------------------------------------
    sketch_box(c, 46, 250, 250, 200, "confs/app2.yaml   (what you wrote)", GREEN, FILL_GREEN, 601, 1.4, 11.5)
    ylines = ["kind: Deployment", "metadata:", "  name: app2", "spec:", "  replicas: 3", "  selector:",
              "    matchLabels:", "      app: app2", "  template:", "    metadata:", "      labels:",
              "        app: app2"]
    y = 412
    for ln in ylines:
        col = RED if "replicas" in ln else (TEAL if "app: app2" in ln else INK)
        txt(c, 58, y, ln, HAND, 9.2, col)
        y -= 13.5

    note(c, 46, 224, ["one number ->", "three running copies"], RED, 16)

    # --- the chain ----------------------------------------------------------
    sketch_box(c, 330, 396, 200, 44, None, GREEN, FILL_GREEN, 611, 1.4)
    ctxt(c, 430, 420, "Deployment  app2", HAND, 11.5, GREEN)
    ctxt(c, 430, 406, "desired: 3", HAND, 8.5, GREY)

    rough_arrow(c, 430, 392, 430, 358, INK, 1.4, 8, 615)
    txt(c, 440, 372, "creates + owns", HAND, 8.5, GREY)

    sketch_box(c, 318, 310, 224, 44, None, TEAL, HexColor(0xE3F2F2), 621, 1.4)
    ctxt(c, 430, 334, "ReplicaSet  app2-574496995c", HAND, 10.5, TEAL)
    ctxt(c, 430, 320, "keeps exactly 3 alive", HAND, 8.5, GREY)

    for i, nm in enumerate(["7mzbm", "fgbqh", "fgjck"]):
        cx = 350 + i * 80
        rough_arrow(c, 430, 306, cx, 262, INK, 1.2, 7, 630 + i)
        pod_shape(c, cx, 232, 30, None, TEAL, HexColor(0xE3F2F2), 640 + i)
        ctxt(c, cx, 238, "pod", HAND, 9, TEAL)
        ctxt(c, cx, 226, nm, HAND, 7.5, GREY)
        ctxt(c, cx, 196, ":8080", HAND, 8.5, INK)

    # --- the service --------------------------------------------------------
    sketch_box(c, 600, 300, 202, 64, None, BLUE, FILL_BLUE, 651, 1.4)
    ctxt(c, 701, 342, "app2-service", HAND, 11.5, BLUE)
    ctxt(c, 701, 328, "ClusterIP 10.43.247.16:80", HAND, 8.5, GREY)
    ctxt(c, 701, 312, "selector:  app = app2", HAND, 9, TEAL)
    for i in range(3):
        cx = 350 + i * 80
        c.setDash(3, 3)
        rough_line(c, 598, 322, cx + 26, 246, BLUE, 1.0, 1, 1.2, 660 + i)
        c.setDash()
    txt(c, 560, 268, "the label is the only link", SCRIPT, 15, BLUE)

    # --- reconcile ----------------------------------------------------------
    sketch_box(c, 46, 62, 366, 122, None, PURPLE, FILL_PURP, 671, 1.3)
    txt(c, 58, 166, "the control loop, forever", HAND, 11.5, PURPLE)
    wrap(c, 58, 150, "Kill a pod and the ReplicaSet notices the count dropped to 2 and starts a third. Change replicas to 5 and the Deployment makes a new ReplicaSet decision. Nothing about this is scripted -- it is a loop comparing desired state to real state.",
         342, HAND, 9.3, 12.8, INK)

    sketch_box(c, 432, 62, 370, 122, None, AMBER, FILL_AMBER, 681, 1.3)
    txt(c, 444, 166, "app1 and app3 are the same shape", HAND, 11.5, AMBER)
    wrap(c, 444, 150, "Identical YAML with replicas: 1 and a different MESSAGE env var. All three run the same image, paulbouwer/hello-kubernetes:1.10, listening on 8080 -- the Service maps port 80 to targetPort 8080.",
         346, HAND, 9.3, 12.8, INK)


def page6(c, n, tot):
    header(c, "One request, end to end", 'curl -H "Host: app2.com" 192.168.56.110  -- eight hops to "Hello from app2"', n, tot)

    top = [("1", "curl on the host", 'Host: app2.com', GREY, FILL_GREY),
           ("2", "vboxnet0", "192.168.56.1", BLUE, FILL_BLUE),
           ("3", "enp0s8 in the VM", "192.168.56.110:80", RED, FILL_RED),
           ("4", "Traefik / ServiceLB", "listening on :80", AMBER, FILL_AMBER)]
    bot = [("5", "Ingress rule match", "host == app2.com", GREEN, FILL_GREEN),
           ("6", "app2-service", "10.43.247.16:80", BLUE, FILL_BLUE),
           ("7", "kube-proxy picks", "1 of 3 endpoints", TEAL, HexColor(0xE3F2F2)),
           ("8", "pod app2-...-fgbqh", "container :8080", PURPLE, FILL_PURP)]

    xs = [46, 244, 442, 640]
    txt(c, 46, 452, "the packet leaves your shell and never touches DNS -- the Host header is just a string in the request",
        SCRIPT, 17, GREY)

    for i, (num, t1, t2, col, fil) in enumerate(top):
        x = xs[i]
        sketch_box(c, x, 318, 162, 100, None, col, fil, 700 + i * 5, 1.3)
        ctxt(c, x + 81, 380, num, SCRIPT, 21, col)
        ctxt(c, x + 81, 358, t1, HAND, 9.8, INK)
        ctxt(c, x + 81, 338, t2, HAND, 8.8, GREY)
        if i:
            rough_arrow(c, x - 34, 368, x - 5, 368, INK, 1.4, 7, 710 + i)

    rough_curve_arrow(c, 721, 314, 721, 254, 34, INK, 1.4, 7, 730)

    for i, (num, t1, t2, col, fil) in enumerate(bot):
        x = xs[3 - i]
        sketch_box(c, x, 150, 162, 100, None, col, fil, 740 + i * 5, 1.3)
        ctxt(c, x + 81, 212, num, SCRIPT, 21, col)
        ctxt(c, x + 81, 190, t1, HAND, 9.8, INK)
        ctxt(c, x + 81, 170, t2, HAND, 8.8, GREY)
        if i:
            rough_arrow(c, x + 196, 200, x + 167, 200, INK, 1.4, 7, 750 + i)

    sketch_box(c, 46, 56, 370, 76, None, GREEN, FILL_GREEN, 761, 1.3)
    txt(c, 58, 112, "Hello from app2", HAND, 13, GREEN)
    txt(c, 58, 94, "Run it ten times and you hit all three pods --", HAND, 9.2, INK)
    txt(c, 58, 82, "that is the Service load-balancing, not Traefik.", HAND, 9.2, INK)

    sketch_box(c, 432, 56, 370, 76, None, RED, FILL_RED, 771, 1.3)
    txt(c, 444, 112, "no Host header?  ->  app3", HAND, 12, RED)
    wrap(c, 444, 94, "Step 5 falls through to the rule with no host: field. That is why a bare curl to the IP answers Hello from app3.",
         346, HAND, 9.2, 12.5, INK)


def page7(c, n, tot):
    header(c, "Things that bite (and why)", "Six failures worth recognising before the evaluation, not during it.", n, tot)

    cards = [
        (46, 300, "rsync is not a live mount", BLUE, FILL_BLUE,
         "ubuntu/jammy64 ships without Guest Additions, so vboxsf cannot mount /vagrant at all. Edits to confs/ reach the VM only on the next `vagrant rsync` or `vagrant provision`."),
        (304, 300, "the second NIC is the real one", RED, FILL_RED,
         "enp0s3 is NAT and identical on every VM. The .110 address lives on enp0s8. setup.sh finds it by IP at runtime -- hardcoding eth1 breaks on Jammy, where names are enp0sN."),
        (562, 300, "192.168.56.0/24 or nothing", AMBER, FILL_AMBER,
         "VirtualBox refuses any other host-only range unless you list it in /etc/vbox/networks.conf. Pick .57.x on a whim and `vagrant up` fails creating the interface."),
        (46, 140, "Secure Boot vs vboxdrv", PURPLE, FILL_PURP,
         "DKMS signs the modules with a key your firmware does not trust, so /dev/vboxdrv never appears and every `vagrant up` dies. Enroll the MOK key, or turn Secure Boot off."),
        (304, 140, "setup.sh runs again, whole", GREEN, FILL_GREEN,
         "`vagrant provision` re-runs it from the top. The K3s installer and kubectl apply are safe to repeat; the KUBECONFIG line in .bashrc is guarded with grep -q."),
        (562, 140, "the node name is lowercase", TEAL, HexColor(0xE3F2F2),
         "The VM hostname is ynassibiS but `kubectl get nodes` shows ynassibis. Kubernetes lowercases object names. Nothing is broken -- do not panic at evaluation."),
    ]
    for x, y, title, col, fil, body in cards:
        h = 145
        sketch_box(c, x, y, 232, h, None, col, fil, 801 + x + y, 1.4)
        rough_line(c, x + 232 - 18, y + h, x + 232, y + h - 18, col, 1.2, 2, 0.8, 900 + x + y)
        yy = wrap(c, x + 13, y + h - 26, title, 200, HAND, 11.5, 15, col)
        wrap(c, x + 13, yy - 3, body, 206, HAND, 9.2, 12.8, INK)

    note(c, 46, 104, ["If curl returns nothing at all, the fault is usually below Kubernetes.",
                      "Check vboxnet0 is UP on the host, then /dev/vboxdrv, then enp0s8 inside the VM -- in that order."], RED, 16, 20)
