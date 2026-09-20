var socket = io();
var socket_creation = true;

var fake_user = null;
var project_name = null;
var editor = null;
var current_tab = null;

var inactivity_timer = null;

var reset_inactivity_ = function() {
    clearTimeout(inactivity_timer);
    inactivity_timer = setTimeout(socket_ask_disconnect, 30 * 60 * 1000)
}

function reset_inactivity() {
    reset_inactivity_();
}

function start_inactivity() {
    reset_inactivity();
    for(e of ["mouseout", "mouseover", "keydown", "click"]) {
        document.addEventListener(e, reset_inactivity);
    }
}

function cancel_inactivity_timer() {
    reset_inactivity_ = () => {};
    clearTimeout(inactivity_timer);
}

function socket_ask_disconnect() {
    var panel = document.getElementById('warn-panel');
    if(panel.classList.contains('hidden'))
        socket_emit("inactivity");
}

socket.on("dialog-disconnect", function(html) {
    show_dialog(html);
    socket.disconnect();
    cancel_inactivity_timer();
});


function app_version() {
    var app = document.getElementById("app");
    if(app) {
        return(app.getAttribute("version") || "Unknown");
    } else {
        return "";
    }
}

function socket_emit(msg, ...args) {
    x = { fake_user: fake_user, proj: project_name, sid: socket.id };
    if(args.length) x["args"] = args[0];
    socket.emit(msg, x); 
}

function alert_msg(msg) {
    socket.emit('alert-warn', msg);
}

function confirm_msg(msg, msg_args, okmsg, cancelmsg,
                     command, command_args) {
    socket.emit('confirm',
                [msg, msg_args, okmsg, cancelmsg,
                 command + '('
                 + JSON.stringify(command_args).slice(1,-1)
                 + ');']);
}

function is_scrolled_view(elem, frac=0.1) {
    var container = elem.offsetParent.parentElement;
    var up = container.scrollTop;
    var height = container.getBoundingClientRect().height;
    if(elem.offsetTop < up + frac*height)
        return false;
    if(elem.offsetTop + elem.offsetHeight > up + (1-frac)*height)
        return false;
    return true;
}

function scroll_into_view(elem) {
    if(! is_scrolled_view(elem))
        elem.scrollIntoView({block: "center"});
}

function fetch_content(url, opts) {
    if(!opts) opts={};
    if(!opts["headers"]) opts["headers"] = {};
    if(fake_user) opts["headers"]["AMC-fake-user"] = fake_user;
    opts["headers"]["AMC-project"] = project_name;
    opts["headers"]["AMC-sid"] = socket.id;
    return fetch(url, opts)
        .then(response => {
            if(!response.ok)
                throw new Error(`Request failed to ${url}`);
            return response.text();
        });
}

function fetch_to_dom(id, url, opts) {
    reset_inactivity();
    var targets = (id instanceof Array) ? id : [ id ];
    return fetch_content(url, opts)
        .then(html => {
            for(i of targets) {
                var e = document.getElementById(i);
                if(e) {
                    e.innerHTML = html;
                }
                else console.error(`Element ${id} not found!`);
            }
        })
        .catch(error => {
            console.error(`Fetch ${url} failed: ${error}`);
            show_fetch_error(targets, url, opts);
        });
}

function show_fetch_error(targets, url, opts) {
    for(var i of targets) {
        var e = document.getElementById(i);
        if(!e) continue;
        e.textContent = "";
        var box = document.createElement("div");
        box.className = "load-error";
        var p = document.createElement("p");
        p.textContent = "Échec du chargement de cette section.";
        var btn = document.createElement("span");
        btn.className = "btn btn-neutral";
        btn.textContent = "Réessayer";
        btn.onclick = function() { fetch_to_dom(targets, url, opts); };
        box.appendChild(p);
        box.appendChild(btn);
        e.appendChild(box);
    }
}

function notify(kind, message, timeout) {
    var box = document.getElementById("toasts");
    if(!box) return;
    var el = document.createElement("div");
    el.className = "toast " + kind;
    var msg = document.createElement("span");
    msg.className = "msg";
    msg.textContent = message;
    var close = document.createElement("button");
    close.className = "x";
    close.setAttribute("aria-label", "Fermer");
    close.textContent = "✕";
    close.onclick = function() { el.remove(); };
    el.appendChild(msg);
    el.appendChild(close);
    box.appendChild(el);
    var t = (timeout === undefined) ? (kind === "err" ? 0 : 3500) : timeout;
    if(t > 0) setTimeout(function() { el.remove(); }, t);
}

function link_to_clipboard(element) {
    setTimeout(()=>{
        element.style.transition = "none";
        var orig_color = element.style.backgroundColor;
        element.style.backgroundColor = "#00e462";
        navigator.clipboard.writeText(element.getAttribute("public-link"));
        setTimeout(()=>{
            element.style.transition = "background-color 3.5s linear";
            element.style.backgroundColor = orig_color; },
                   1500);
    });
}

// -----------------------------------------------------------------

function show_tab(tab_name) {
    if(current_tab == "source" && source_dirty
       && tab_name.replace(/_.*/, "") != "source") {
        // promesse jamais résolue : le .then() de l'appelant ne doit pas
        // charger l'onglet suivant alors qu'on reste sur la source
        if(!confirm("La source contient des modifications non enregistrées. Continuer ?"))
            return new Promise(function() {});
    }
    return fetch_to_dom('tab', `/tab/${tab_name}`, {})
        .then(()=> { set_current_tab(tab_name); });
}

function set_hash_url() {
    location.hash = (current_tab == "main" ? "" : project_name)
        + "/" + (current_tab || "");
}

function set_current_tab(tab_name) {
    tab_name = tab_name.replace(/_.*/, "");
    current_tab = tab_name;
    for(var e of document.getElementsByClassName("menubtn")) {
        var name = e.id.substring(5);
        if(name == current_tab) e.classList.add("current");
        else e.classList.remove("current");
    }
    set_hash_url();
}

function adapt_menu(data) {
    for(var e of document.getElementsByClassName("adapt-menu")) {
        var name = e.id.substring(5);
        if(data[name]) e.classList.remove("hidden");
        else e.classList.add("hidden");
    }
}

socket.on("menu", adapt_menu);

function connection_status(s) {
    var cs = document.getElementById('connection-status');
    if(cs) {
        for(x of ["online", "offline"]) {
            if(x==s) cs.classList.add(x);
            else cs.classList.remove(x);
        }
    } else {
        console.error("Can't find connection-status")
    }
}

function set_theme(t) {
    document.documentElement.setAttribute("data-theme", t);
    try { localStorage.setItem("amc-theme", t); } catch(e) {}
}

function toggle_theme() {
    var dark = document.documentElement.getAttribute("data-theme") == "dark";
    set_theme(dark ? "light" : "dark");
}

// ----------------------- STEPPER

// ponytail: libellés littéraux faute de clés i18n amont ; à extraire si besoin
var workflow_steps = [
    ["project", "Projet prêt"],
    ["scans", "Copies scannées"],
    ["marks", "Notes calculées"],
    ["export", "Export"],
];
var workflow_state = { project: false, scans: false, marks: false, export: false };
var workflow_project = undefined;

function set_workflow(key, value) {
    if(!(key in workflow_state)) return;
    if(workflow_state[key] == value) return;
    workflow_state[key] = value;
    render_workflow();
}

function reset_workflow(project) {
    workflow_state = { project: !!project, scans: false, marks: false, export: false };
    render_workflow();
}

function render_workflow() {
    var el = document.getElementById("workflow");
    if(!el) return;
    var active_set = false;
    var html = "";
    for(var i = 0; i < workflow_steps.length; i++) {
        var key = workflow_steps[i][0];
        var done = workflow_state[key];
        var cls = done ? "done" : (active_set ? "" : "active");
        if(!done) active_set = true;
        html += '<div class="step ' + cls + '">'
              + '<span class="pip">' + (done ? "✓" : (i + 1)) + '</span>'
              + '<span class="t">' + workflow_steps[i][1] + '</span></div>';
    }
    el.innerHTML = html;
}

var projects_action = "project-open";

function select_action(e) {
    projects_action = e.id;
    for(x of document.getElementsByClassName("project-action")) {
        x.classList.remove("selected");
    }
    for(var pul of document.getElementsByClassName("projects-ul")) {
        for(c of ["ok", "neutral", "danger"]) {
            if(e.classList.contains(c)) pul.classList.add(c);
            else pul.classList.remove(c);
        }
    }
    e.classList.add("selected");
}

function project_rename(element, name) {
    inp = document.createElement("input");
    inp.setAttribute("type", "text");
    inp.setAttribute("id", "project-rename");
    inp.setAttribute("name", "project-rename");
    inp.setAttribute("onchange", "project_do_rename(this);");
    inp.setAttribute("onkeyup", "project_rename_key(this, event);");
    inp.setAttribute("oldname", name);
    inp.setAttribute("class", "project-change-name");
    inp.value = name;
    element.textContent = "";
    element.setAttribute("onclick", "");
    element.appendChild(inp);
    inp.focus();
}

function project_rename_key(e, event) {
    if(event.key === "Escape") {
        var name = e.getAttribute("oldname");
        var p = e.parentElement;
        p.innerHTML = '';
        p.textContent = name;
    }
}

function project_do_rename(e) {
    socket_emit("project-rename", [e.getAttribute("oldname"), e.value]);
}

function request_project(name, reload) {
    if(name == "__sleep__") {
        socket_emit("sleep", reload);
    } else {
        socket_emit("request-project", [name, reload]);
    }
}

function set_project_title(n_printing=0) {
    var title = '';
    if(n_printing>0) {
        title += `[${n_printing}] `;
    }
    title += project_name;
    document.title = title;
}

function project_open(data) {
    var name = data[0];
    document.getElementById('project-name').textContent = name;
    localStorage.setItem("project-name", name);
    if(name != project_name || data[1]) {
        project_name = name;
        socket_emit('adapt-menu');
        if(name) {
            switch(data[1]) {
            case "main":
                tab_main();
                break;
            case "scans":
                tab_scans();
                break;
            case "grading":
                tab_grading();
                break;
            case "config":
                tab_config();
                break;
            default:
                tab_source();
            }
        } else tab_main();
    }
    set_project_title();
    if(name != workflow_project) {
        workflow_project = name;
        reset_workflow(name);
    } else {
        set_workflow("project", !!name);
    }
}
socket.on("project-open", project_open );

function do_fake_user(u) {
    fake_user = u;
    document.getElementById("menu-admin-back").setAttribute("title", u);
}

function select_project(element, name, user=null) {

    if(user) do_fake_user(user);
    
    if(name) {
        switch(projects_action) {
        case "project-open":
            request_project(name, true);
            break;
        case "project-rename":
            project_rename(element, name);
            break;
        case "project-delete":
            confirm_msg('confirm.deleteproject', [name],
                        'continue:danger', 'cancel:neutral',
                        'socket_emit', [projects_action, name]);
            break;
        case "project-clone":
            socket_emit(projects_action, name);
            break;
        case "project-download":
            window.location.href = element.getAttribute("amc-url");
            break;
        default:
            console.log(`Unknown action: ${projects_action}.`);
        }
    } else {
        socket_emit('adapt-menu');
        tab_main();
    }
}

function admin_back() {
    do_fake_user(null);
    request_project("", true);
}

function admin_search() {
    if(current_tab == "main") {
        projects_action = "project-open";
        fetch_to_dom('projects-list', "/projects_list.html?all=1", {});
    }
}

function u_projects_list() {
    projects_action = "project-open";
    fetch_to_dom('projects-list', "/projects_list.html", {});
}
socket.on("u-projects-list", u_projects_list);

function filter_projects(e) {
    var q = e.value.toLowerCase();
    for(var c of document.querySelectorAll("#projects-list .project-card")) {
        c.style.display = c.textContent.toLowerCase().includes(q) ? "" : "none";
    }
}

function project_action(action, element, name, user=null) {
    if(user) do_fake_user(user);
    switch(action) {
    case "open":
        request_project(name, true);
        break;
    case "rename":
        project_rename(element.closest(".project-card").querySelector(".pc-name"), name);
        break;
    case "clone":
        socket_emit("project-clone", name);
        break;
    case "delete":
        confirm_msg('confirm.deleteproject', [name],
                    'continue:danger', 'cancel:neutral',
                    'socket_emit', ["project-delete", name]);
        break;
    case "download":
        window.location.href = element.closest(".project-card").getAttribute("amc-url");
        break;
    default:
        console.log(`Unknown project action: ${action}.`);
    }
}

function tab_main() {
    show_tab("main").then(() => {
        u_projects_list();
        fetch_to_dom('project-new' , "/project_new.html", {});
    });
}

function tab_config() {
    show_tab("config")
        .then(() => {
            socket_emit("project-config");
        });
}

function template_group_select(gid) {
    var tlist = document.getElementById('template-list');
    for (t of tlist.children) {
        if(t.getAttribute("gid") === gid || gid === "")
            t.classList.remove("hidden");
        else
            t.classList.add("hidden");
    }
}

function upload_files(url, files,
                      message,
                      params={}, callback=null) {
    const formData = new FormData();
    for(var f of files) {
        if(f instanceof Array) 
            formData.append('file', ...f);
        else
            formData.append('file', f);
    }
    for(var k of Object.keys(params)) {
        formData.append(k, params[k]);
    }
    const xhr = new XMLHttpRequest();
    current_upload_xhr = xhr;
    xhr.open('POST', url, true);
    xhr.setRequestHeader("AMC-project", project_name);
    if(fake_user)
        xhr.setRequestHeader("AMC-fake-user", fake_user);
    xhr.setRequestHeader("AMC-sid", socket.id);
    xhr.upload.onprogress = e => {
        if (e.lengthComputable) {
            set_p(e.loaded / e.total);
        }
    };
    xhr.onreadystatechange = () => {
        if (xhr.readyState == XMLHttpRequest.DONE) {
            if (xhr._cancelled) return;
            current_upload_xhr = null;
            if (xhr.status === 200) {
                console.log("Upload response: " + xhr.responseText);
                var r = JSON.parse(xhr.responseText);
                if(r["ok"]) {
                    if(callback) callback(r);
                } else {
                    alert_msg(r["error"]);
                }
            } else {
                notify('err', `Échec de l'envoi (statut ${xhr.status}).`);
            }
        }
    };
    begin_command(message, true);
    xhr.send(formData);
}

function upload_file_to_project_done(r) {
    all_files_change();
}

function upload_file_to_project() {
    var f = document.getElementById('project-upload-file');
    if(f.files.length) {
        upload_files("/upload/project",
                     f.files, "Uploading…", {},
                     upload_file_to_project_done
                    );
    }
}

function delete_project_file(filename) {
    var all_files = document.getElementById("all-files").checked;
    confirm_msg('confirm.deletefile', [filename],
                'continue:danger', 'cancel:neutral',
                'socket_emit', ["project-delete-file", [filename, all_files]])
}

function do_create_project() {
    var name = document.getElementById('new-project-name').value;
    var way = document.querySelector('input[name="way"]:checked').value;
    if(name === "") {
        alert_msg('create.project.noname');
        return;
    }
    if(way == "empty") {
        var stype = document.getElementById('source-type').value;
        socket_emit("create-project-empty", [name, stype]);
    } else if(way == "template") {
        var tid = document.querySelector('input[name="tid"]:checked');
        if(tid === null) {
            alert_msg('create.project.notemplate');
            return;
        }
        tid = tid.value;
        socket_emit("create-project-template", [name, tid]);
    } else if(way == "file") {
        var f = document.getElementById('source-file');
        if(f.files.length) {
            upload_files("/upload/create",
                         f.files, "Uploading…",
                         { "name": name }
                        )
        } else {
            alert_msg('create.project.nofile');
        }
    } else {
        console.error("Unknown way: " + way)
    }
}

socket.on("source-name", function(data) {
    var name = data[0];
    var mode = data[1];
    var url = data[2];
    var cc = document.getElementById('code-code');
    if(cc) {
        if(!editor) {
            editor = ace.edit("code-code");
            editor.setTheme("ace/theme/textmate");
            editor.session.on('change', function(delta) {
                source_modified(true);
            });
        }
        editor.session.setMode("ace/mode/" + mode);
        fetch_content(url, {})
            .then(code_text => {
                editor.session.setValue(code_text, -1);
            })
            .then(() => {
                source_modified(false);
                var fl = document.getElementById("files-list");
                if(fl) {
                    fl.classList.add("hidden");
                }
                var cn = document.getElementById('source-name');
                if(cn) {
                    cn.textContent = name;
                } else {
                    console.log("Warning: source-name not found");
                }
            });
    }
});

socket.on("ncopies", function(n) {
    var nc = document.getElementById('ncopies');
    if(nc) {
        nc.value = n;
    }
});

var source_dirty = false;

function source_modified(t) {
    source_dirty = !!t;
    for(const i of ["source-save", "source-revert"]) {
        var b = document.getElementById(i);
        if(b) {
            if(t) b.classList.remove("disabled");
            else b.classList.add("disabled");
        }
    }
    var d = document.getElementById("source-dirty");
    if(d) {
        if(t) d.classList.remove("hidden");
        else d.classList.add("hidden");
    }
}

socket.on("source-saved", function() {
    source_modified(false);
    notify('ok', "Source enregistrée.");
});

function select_file(f) {
    var cn = document.getElementById('source-name');
    if(cn) {
        cn.textContent = f;
        source_revert();
    }
}

function all_files_change() {
    var all_files = document.getElementById("all-files").checked;
    fetch_to_dom("files-list-list",
                 "/files_list.html" + (all_files ? "?all=1" : ""), {});
}

socket.on("project-files-list", all_files_change);

function source_other() {
    var fl = document.getElementById("files-list");
    if(fl.classList.contains("hidden")) {
        fl.classList.remove("hidden");
        document.getElementById("all-files").checked = false;
        all_files_change();
    } else {
        fl.classList.add("hidden");
    }
}

function source_revert() {
    var cn = document.getElementById('source-name');
    if(cn) {
        socket_emit("source-code", cn.textContent);
    }
}

function source_save() {
    var cn = document.getElementById('source-name');
    var fn = cn.textContent;
    upload_files("/upload/source",
                 [ [ new Blob([editor.getValue()],
                              { type: 'text/plain' }),
                     fn ] ], "Uploading…",
                 {}, null);
}

function tab_source() {
    editor = null;
    show_tab("source").then(() => {
        socket_emit("source-info");
        socket_emit("source-code", "");
        update_printing();
    });
}

function restore_project() {
    if(location.hash) {
        var pt = location.hash.split("/");
        pt[0] = pt[0].replace("#","");
        request_project(...pt);
    } else {
        project_name = localStorage.getItem("project-name");
        if(project_name) {
            request_project(project_name, true);
        } else {
            request_project("", true);
        }
    }
}

socket.on("connect", () => {
    connection_status("online");
    socket_emit("is-online", app_version());
    if(socket_creation) {
        socket_creation = false;
        restore_project();
    } else {
        request_project(project_name, false);
    }
});

socket.on("reload", () => {
    location.reload();
});

socket.on("disconnect", () => {
    connection_status("offline");
});

function change_ncopies() {
    socket_emit("ncopies",
                document.getElementById('ncopies').value);
}

socket.on("document-content", function(data) {
    var can_print = data[0];
    var danger = data[1];
    var type = data[2];
    var url = data[3];
    
    var pb = document.getElementById('doc-print-btn');
    if(pb) {
        if(can_print) pb.classList.remove("hidden");
        else pb.classList.add("hidden");
    }
    var du = document.getElementById('doc-update');
    if(du) {
        if(document.getElementById('doc-type').value)
            du.classList.remove('disabled');
        else du.classList.add('disabled');

        if(danger) du.classList.add('danger');
        else du.classList.remove('danger');
    }
    fetch_to_dom("document-view", `/document/${type}`,
                 { method: 'POST',
                   headers: {
                       'Content-Type': 'application/json',
                   },
                   body: JSON.stringify({
                       url: url })
                 })
        .then(() => {
            if(type == "calage") {
                socket_emit("layout-init");
            }
        });
});

socket.on("defects", function(cl) {
    var db = document.getElementById('defects-button');
    if(cl) {
        db.classList.remove("hidden");
        fetch_to_dom("defects-list", "/defects_list.html", {});
    } else {
        db.classList.add("hidden");
        document.getElementById('defects-list').classList.add("hidden");
    }
});

function toggle_defects_view() {
    var dv = document.getElementById('defects-list');
    if(dv.classList.contains("hidden"))
        dv.classList.remove("hidden");
    else
        dv.classList.add("hidden");
}

function change_doc_type(e) {
    var t = e.value;
    var upd = document.getElementById('doc-update');
    if(t == "calage") upd.classList.add("hidden");
    else upd.classList.remove("hidden");
    socket_emit("doc-type", t);
}

function doc_update(e) {
    if(e.classList.contains("danger")) {
        confirm_msg('confirm.rebuild', [],
                    'continue:danger', 'cancel:neutral',
                    'socket_emit', ["doc-update",
                                    document.getElementById('doc-type').value]);
    } else {
        socket_emit("doc-update",
                    document.getElementById('doc-type').value);
    }
}

function set_t(text) {
    reset_inactivity();
    var panel = document.getElementById('info-text');
    panel.textContent = text;
}

function set_p(prop) {
    reset_inactivity();
    var pc = 100.0*prop;
    var prog = document.getElementById('info-prop');
    prog.value = pc;
    prog.textContent = pc.toFixed(1) + " %";
}

socket.on("t", set_t);

socket.on("p", set_p);

var current_upload_xhr = null;

function begin_command(message="", cancellable=false) {
    set_t(message);
    set_p(0);
    var btn = document.getElementById('info-cancel');
    if(btn) {
        if(cancellable) btn.classList.remove('hidden');
        else btn.classList.add('hidden');
    }
    var panel = document.getElementById('info-panel');
    panel.classList.remove('hidden');
}

socket.on("begin-command", function(m) { begin_command(m, false); });

function cancel_command() {
    if(current_upload_xhr) {
        current_upload_xhr._cancelled = true;
        current_upload_xhr.abort();
        current_upload_xhr = null;
        notify('warn', "Envoi annulé.");
    }
    end_command();
}

function end_command() {
    current_upload_xhr = null;
    var panel = document.getElementById('info-panel');
    panel.classList.add('hidden');
}

socket.on("end-command", end_command);

function show_dialog(html) {
    var w = document.getElementById('warn-content');
    w.innerHTML = html;
    var panel = document.getElementById('warn-panel');
    panel.classList.remove('hidden');
}

socket.on("dialog", show_dialog);

function warn_ok() {
    var panel = document.getElementById('warn-panel');
    panel.classList.add('hidden');
}

function layout_add(delta) {
    var p = document.getElementById('layout-page');
    socket_emit("layout-add", [p.textContent, delta]);
}

socket.on("layout-set-page", function(data) {
    var p = document.getElementById('layout-page');
    if(p) p.textContent = data[0];
    var o = document.getElementById('layout-svg');
    if(o) o.setAttribute("data", data[1])
});

function doc_print() {
    document.getElementById('code').classList.add("hidden");
    document.getElementById('print').classList.remove("hidden");
    fetch_to_dom("print", "/print_dialog.html", {});
}

function doc_print_finished() {
    document.getElementById('code').classList.remove("hidden");
    document.getElementById('print').classList.add("hidden");
}

socket.on("print-done", function(data) {
    doc_print_finished();
    setTimeout(update_printing, 1000);
});

function print_range() {
    return [document.getElementById('student1').value,
            document.getElementById('student2').value];
}

function print_to_printer() {
    var p = document.getElementById('printer').value;
    socket_emit("print-to-printer",
                [ ...print_range(), p]);
}

function update_printing() {
    socket_emit("n-waiting-print");
}

socket.on("n-waiting-print", function(data) {
    reset_inactivity();
    var n = parseInt(data);
    var ps = document.getElementById("printing-status");
    set_project_title(n);
    if(ps) {
        if(n>0) ps.classList.remove("hidden");
        else ps.classList.add("hidden");
        document.getElementById("printing-status-n").textContent = data;
    }
    if(n>0) setTimeout(update_printing, 2000);
});

function cancel_printing() {
    socket_emit("cancel-printing");
}

function print_to_files() {
    var b = document.getElementById('print-files-btn');
    socket_emit("print-to-files", print_range());
}

function open_file(url) {
    window.location.href = url;
}

socket.on("print-to-files", function(url) {
    open_file(url);
    doc_print_finished();
    notify('ok', "Fichiers d'impression générés.");
});

function show_multimode(ok) {
    mm = document.getElementById('multi-mode');
    if(mm) {
        if(ok) mm.classList.remove("hidden");
        else mm.classList.add("hidden");
    }
}

function scans_mode_change() {
    var m = document.getElementById('scans-photocopied').checked;
    show_multimode(m);
    socket_emit("scans-mode-change", (m ? 1 : 0));
}

socket.on("scans-mode", function(m) {
    var sm = document.getElementById('scans-photocopied');
    show_multimode(m==1);
    if(sm) {
        sm.checked = (m == 1);
    }
});

function scanslist_allcols_change(e) {
    var t = document.getElementById('scans-pages');
    if(t) {
        if(e.checked) t.classList.add("all-columns");
        else t.classList.remove("all-columns");
    }
    change_config_value(e);
}

socket.on("lock-photocopy", function() {
    var p = document.getElementById('scans-photocopied');
    p.disabled = true;
});
socket.on("unlock-photocopy", function() {
    var p = document.getElementById('scans-photocopied');
    p.disabled = false;
});

socket.on("thresholds", function(data) {
    var d;
    d = document.getElementById("threshold");
    if(d) d.value = parseFloat(data[0]);
    d = document.getElementById("threshold-up");
    if(d) d.value = parseFloat(data[1]);
});

function threshold_change() {
    var threshold = document.getElementById("threshold").value;
    var threshold_up = document.getElementById("threshold-up").value;
    fetch_to_dom("scans-report", "/set_thresholds.html",
                 { method: "POST",
                   headers: {
                       'Content-Type': 'application/json'
                   },
                   body: JSON.stringify({
                       seuil: threshold, seuil_up: threshold_up })
                 });
}

function update_scans_workflow() {
    var ok = document.querySelector("#report-numbers > div.ok");
    set_workflow("scans", ok ? parseInt(ok.textContent) > 0 : false);
}

function u_scans_report() {
    return fetch_to_dom("scans-report", "/scans_report.html", {})
        .then(update_scans_workflow);
}

socket.on("scans-report", u_scans_report);

function tab_scans() {
    show_tab("scans").then(() => {
        socket_emit("scans-mode");
        socket_emit("scans-params");
        u_scans_report();
    });
}

socket.on("tab-scans", tab_scans);

function failed_clear_img() {
    for(var n of ["failed-orig-img", "failed-pp-img"])
        document.getElementById(n).setAttribute("src", "");
    var c = document.getElementById("failed-compare");
    if(c) c.classList.remove("has-pp");
    failed_set_split(50);
}

// Comparateur avant/après : le volet prétraité est révélé à droite du curseur.
function failed_set_split(v) {
    v = Number(v);
    var pp = document.getElementById("failed-pp-img");
    var h = document.querySelector("#failed-frames .cmp-handle");
    if(pp) pp.style.clipPath = `inset(0 0 0 ${v}%)`;
    if(h) h.style.left = v + "%";
}

function u_scans_failed_report() {
    return fetch_to_dom("failed-report", "/failed_report.html", {})
        .then(() => {
            var s = document.getElementsByClassName("failed-scan");
            if(s.length) {
                failed_scan_view(s[0]);
            }
        });
}

socket.on("failed-report", u_scans_failed_report);

function tab_scans_failed() {
    show_tab("scans_failed").then(() => {
        u_scans_failed_report();
    });
}

function failed_set_pp_url(url) {
    document.getElementById("failed-pp-img")
        .setAttribute("src", url);
    var c = document.getElementById("failed-compare");
    if(c) {
        if(url) c.classList.add("has-pp");
        else c.classList.remove("has-pp");
    }
    var s = document.getElementById("failed-slider");
    if(s) s.value = 50;
    failed_set_split(50);
}

function failed_scan_view(e) {
    var url = e.getAttribute("amc-scan-url");
    document.getElementById("failed-orig-img")
        .setAttribute("src", url);
    failed_set_pp_url("");
    var t = document.getElementById("failed-scans");
    for(x of t.getElementsByClassName("scan-file selected"))
        x.classList.remove("selected");
    e.classList.add("selected");
}

function failed_selected_filename() {
    var t = document.getElementById("failed-scans");
    x = t.getElementsByClassName("scan-file selected");
    if(x.length)
        return x[0].getAttribute("amc-filename");
    else
        return null;
}

socket.on("failed-pp-url", function(url) {
    failed_set_pp_url(url);
});

function failed_pre_process() {
    fn = failed_selected_filename();
    if(fn) socket_emit("failed-pre-process", fn);
}

function failed_delete() {
    fn = failed_selected_filename();
    if(fn) socket_emit("failed-delete", fn);
}

function update_zoom_ticked(question, answer) {
    var x = document.getElementById("box1_" + question + "_" + answer);
    if(x) {
        var y;
        for(y of document.querySelectorAll("div[amc-question=\"" + question + "\"][amc-answer=\"" + answer + "\"]")) {
            if(x.classList.contains("ticked")) {
                y.classList.remove("not-ticked");
                y.classList.add("ticked");
            } else {
                y.classList.remove("ticked");
                y.classList.add("not-ticked");
            }
        }
    } else {
        console.log("Rect not found", question, answer);
    }
}

function update_all_zooms_ticked() {
    var x;
    for(x of document.getElementsByClassName("box1")) {
        var i = x.getAttribute("id").split("_");
        update_zoom_ticked(i[1], i[2]);
    }
    setTimeout(() => {
        var z;
        z = document.getElementById('zooms-0');
        z.scrollTo(0, z.scrollHeight);
        z = document.getElementById('zooms-1');
        z.scrollTo(0, 0);
    });
}

function allow_manual_revert(ok) {
    var r = document.getElementById("manual-revert");
    if(ok) {
        r.classList.remove("hidden");
    } else {
        r.classList.add("hidden");
    }
    r = document.getElementsByClassName("selected pagerow")[0];
    r.setAttribute("amc-manual", ok ? "1" : "0");
}

socket.on("allow-revert", ()=> allow_manual_revert(true));
socket.on("disallow-revert", ()=> allow_manual_revert(false));

function revert_manual() {
    var v = document.getElementById('manual-view');
    socket_emit(
        "revert-manual",
        [ v.getAttribute("amc-student"),
          v.getAttribute("amc-page"),
          v.getAttribute("amc-copy") ]
    );
}

function highlight_selected_page(e, student, page, copy) {
    if(e == null) {
        e = document.querySelector(`.pagerow[amc-student="${student}"][amc-page="${page}"][amc-copy="${copy}"]`);
    }
    for(old of document.getElementsByClassName("selected pagerow")) {
        old.classList.remove("selected");
    }
    if(e) {
        e.classList.add("selected");
        scroll_into_view(e);
    }
}

var to_rm_point = null;

function no_page_select() {
    document.getElementById("zooms-0").innerHTML = '';
    document.getElementById("zooms-1").innerHTML = '';
    fetch_to_dom("manual", "/scans_page_none.html")
}

function scans_page_select(e, student, page, copy, event=null) {
    if(to_rm_mode() && event) {
        to_rm_action(e, event);
        return;
    }
    highlight_selected_page(e, student, page, copy);
    fetch_to_dom("manual", "/scans_page_select.html",
                 { method: "POST",
                   headers: {
                       'Content-Type': 'application/json'
                   },
                   body: JSON.stringify({
                       student: student, page: page, copy: copy,
                       question: q_select()
                   })
                 })
        .then(() => {
            var s = document.getElementsByClassName("selected pagerow")[0];
            allow_manual_revert(s.getAttribute("amc-manual") == "1"
                                && q_select() == null);
        })
        .then(() => {
            fetch_to_dom(["zooms-0", "zooms-1"],
                         `/zooms/${student}/${page}/${copy}`,
                         {})
                .then(update_all_zooms_ticked);
        });
}

socket.on("scans-page-select", function(data) {
    u_scans_report()
        .then(() => {
            scans_page_select(null, ...data);
        });
});

function to_rm_action(e, event) {
    if(event.shiftKey) {
        var next_function;
        var c = e.compareDocumentPosition(to_rm_point);
        if(c & 0x04) {
            next_function = ((e) => e.nextElementSibling);
        } else if(c & 0x02) {
            next_function = ((e) => e.previousElementSibling);
        } else {
            return;
        }
        while(e != null) {
            e.classList.add("to-rm");
            if(e == to_rm_point) e = null;
            else e = next_function(e);
        }
    } else if(event.ctrlKey) {
        e.classList.toggle("to-rm");
        to_rm_point = e;
    } else {
        clear_to_rm();
        e.classList.add("to-rm");
        to_rm_point = e;
    }
}

function to_rm_mode() {
    return document.getElementById('pages-delete-start').classList.contains("hidden");
}

function start_delete_pages() {
    document.getElementById('pages-delete-start').classList.add("hidden");
    document.getElementById('pages-delete-stop').classList.remove("hidden");
    document.getElementById('pages-delete-do').classList.remove("hidden");
}

function clear_to_rm() {
    t = document.getElementById('scans-pages');
    for(e of Array.from(t.getElementsByClassName('to-rm'))) {
        e.classList.remove('to-rm');
    }
}

function stop_delete_pages() {
    clear_to_rm();
    document.getElementById('pages-delete-start').classList.remove("hidden");
    document.getElementById('pages-delete-stop').classList.add("hidden");
    document.getElementById('pages-delete-do').classList.add("hidden");
}

function do_delete_pages() {
    t = document.getElementById('scans-pages');
    var to_rm = [];
    for(e of t.getElementsByClassName('to-rm')) {
        s = {};
        for(var k of ['student', 'page', 'copy']) {
            s[k] = e.getAttribute('amc-' + k);
        }
        if(e.classList.contains("selected"))
            no_page_select();
        to_rm.push(s);
    }
    if(to_rm.length) {
        socket_emit("delete-scans", to_rm);
    }
    stop_delete_pages();
}

function row_spc(row) {
    return [ row.getAttribute("amc-student"),
             row.getAttribute("amc-page"),
             row.getAttribute("amc-copy") ];
}

function selected_pagerow() {
    return document.getElementById("scans-pages-rows")
        .getElementsByClassName("pagerow selected");
}

function first_pagerow() {
    var x= document.getElementById("scans-pages-rows")
        .getElementsByClassName("pagerow");
    if(x.length) return(x[0]);
    else return(null);
}

function scans_page_move(move_function) {
    var sel = selected_pagerow();
    var target = null;

    if(sel.length) {
        target = move_function(sel[0]);
    } else {
        target = first_pagerow();
        move_function = (e) => e.nextElementSibling;
    }

    while(target != null && target.classList.contains("hidden")) {
        target = move_function(target);
    }

    if(target)
        scans_page_select(target, ...row_spc(target));
    return target;
}

function scans_page_reload() {
    var sel = selected_pagerow();
    if(sel.length) {
        scans_page_select(sel[0], ...row_spc(sel[0]));
    }
}

function scans_page_move_up() {
    scans_page_move((e) => e.previousElementSibling);
}
function scans_page_move_down() {
    scans_page_move((e) => e.nextElementSibling);
}

socket.on("tick-box", function(data) {
    var question = data[0];
    var answer = data[1];
    var ticked = data[2];
    var b = document.getElementById(`box1_${question}_${answer}`);
    if(b) {
        if(ticked)
            b.classList.add("ticked");
        else
            b.classList.remove("ticked");
    }
    update_zoom_ticked(question, answer);
});

function compare_reports(a, b, column) {
    var x = 0;
    if(column) {
        x = parseFloat(b.getAttribute("amc-" + column)) - parseFloat(a.getAttribute("amc-" + column));
    }
    if(x==0) {
        x = parseInt(a.getAttribute("amc-student")) - parseInt(b.getAttribute("amc-student"));
    }
    if(x==0) {
        x = parseInt(a.getAttribute("amc-copy")) - parseInt(b.getAttribute("amc-copy"));
    }
    if(x==0) {
        x = parseInt(a.getAttribute("amc-page")) - parseInt(b.getAttribute("amc-page"));
    }
    return(x);
}

function scans_report_sort(column) {
    var rows = Array.from(document.getElementsByClassName("pagerow")).sort((a,b)=> compare_reports(a,b,column));
    var c = document.getElementById("scans-pages-rows");
    for(var r of rows) {
        c.appendChild(r);
    }
    var sel = selected_pagerow();
    if(sel.length) scroll_into_view(sel[0]);
}

function q_select() {
    var qs = document.getElementById("q-select");
    if(qs) {
        if(qs.value == "") return null;
        else return qs.value;
    } else
        return null;
}

function q_select_set(pages_list) {
    var pages = document.getElementById("scans-pages-rows");
    if(pages_list == null || pages_list == []) {
        // All pages available
        for(var p of pages.getElementsByClassName("pagerow"))
            p.classList.remove("hidden");
    } else {
        with_q = new Set();
        for(var x of pages_list) {
            with_q.add(x[0] + "-" + x[1])
        }
        for(var p of pages.getElementsByClassName("pagerow")) {
            if(with_q.has(p.getAttribute("amc-student") + "-"
                          + p.getAttribute("amc-page")))
                p.classList.remove("hidden");
            else
                p.classList.add("hidden");
        }
    }
    // Move to next available page if necessary
    var sel = selected_pagerow();
    if(sel.length) {
        if(sel[0].classList.contains("hidden")) {
            if(!scans_page_move_down()) scans_page_move_up();
        } else {
            scans_page_reload();
        }
    }
}

function q_select_change(e) {
    var question_number = e.value;
    if(question_number) {
        // Download list of pages with this question
        fetch(`/pages/${question_number}`,
              { headers: { "AMC-Project": project_name,
                           "AMC-sid": socket.id }})
            .then(function(response) {
                return response.json();
            })
            .then(function(j) {
                q_select_set(j);
                document.getElementById('zooms').classList.add("hidden");
            });
    } else {
        q_select_set(null);
        document.getElementById('zooms').classList.remove("hidden");
    }
}

function clickBox(question, answer) {
    var mv = document.getElementById('manual-view');
    var b = document.getElementById(`box1_${question}_${answer}`);
    if(mv && b) {
        console.log(`Click on box(${question}/${answer})`);
        var all_page = (q_select() == null);
        var ticked = !b.classList.contains("ticked");
        socket_emit("set-manual",
                    [ mv.getAttribute("amc-student"),
                      mv.getAttribute("amc-page"),
                      mv.getAttribute("amc-copy"),
                      question, answer, ticked, all_page ]);
    }
}

function upload_scans_done(r) {
    console.log("Scans uploaded: start data capture");
    socket_emit("data-capture", r["list"]);
}

function upload_scans() {
    var f = document.getElementById('scans-upload');
    if(f.files.length) {
        upload_files("/upload/scans",
                     f.files, "Uploading…", { "project_name": project_name },
                     upload_scans_done
                    );
    }
}

function add_student() {
    var student = document.getElementById('add-student-n').value;
    if(student.match(/^[0-9]+(:[0-9]+)?$/)) {
        socket_emit("add-student", student);
        document.getElementById('add-student-n').value = "";
    } else {
        socket_emit("add-student-syntax");
    }
}

// ----------------------- GRADING

socket.on("n-marks", function(n) {
    for(var id of ["block-export", "block-annotate"]) {
        var e = document.getElementById(id);
        if(e) {
            if(n>0) e.classList.remove("hidden");
            else e.classList.add("hidden");
        }
    }
    set_workflow("marks", n > 0);
});

function u_marks() {
    fetch_to_dom("marks-report", "/show_marks.html", {});
}
socket.on("update-marks", u_marks);

socket.on("export-available", function(a) {
    for (const [key, value] of Object.entries(a)) {
        var e = document.getElementById(key);
        if(e) {
            if(value instanceof Array) {
                for(opt of e.getElementsByTagName("option")) {
                    if(value.includes(opt.value))
                        opt.classList.remove("hidden")
                    else opt.classList.add("hidden");
                }
            } else {
                if(value) e.classList.remove("hidden");
                else e.classList.add("hidden");
            }
        }
    }
});

function n_incomplete_details() {
    socket_emit("n-incomplete-details");
}

function students_install() {
    var shared = document.getElementById("students-shared").value;
    if(shared) {
        socket_emit("studentslist-shared", shared);
        return false;
    } else {
        return true;
    }
}

function upload_students_done() {
    u_identification();
}

function upload_students() {
    var f = document.getElementById('students-upload');
    if(f.files.length) {
        upload_files("/upload/students",
                     f.files, "Uploading…", {},
                     upload_students_done
                    );
    }
}

function students_list_delete(ask_confirm) {
    if(ask_confirm) {
        confirm_msg('confirm.rmstudentslist', [],
                    'continue:danger', 'cancel:neutral',
                    'socket_emit', ["studentslist-delete"]);
    } else {
        socket_emit("studentslist-delete");
    }
}

function u_identification() {
    fetch_to_dom("identification", "/identification.html", {})
        .then( () => {
            var nid = document.getElementById("n-identifications");
            var n = 0;
            if(nid) n = parseInt(nid.getAttribute("n-ok"));
            var pm = document.getElementById("public-marks");
            if(n>0) pm.classList.remove("hidden");
            else pm.classList.add("hidden");
            var sw = document.getElementById("grading-switch");
            if(sw) {
                var has_list = document.querySelector("#identification .filename") != null;
                if(has_list) sw.classList.remove("hidden");
                else sw.classList.add("hidden");
            }
        });
}
socket.on("update-identification", u_identification);

function u_exported_files(t) {
    fetch_to_dom("exported-files", "/exported_files.html",
                 {
                     method: "POST",
                     headers: {
                         'Content-Type': 'application/json'
                     },
                     body: JSON.stringify({ t: t})
                 })
        .then( () => {
            if(t) flash_files(document.getElementById("exported-files"));
        });
}
socket.on("update-exported-files", u_exported_files);
socket.on("update-exported-files", function(t) {
    if(t) {
        set_workflow("export", true);
        notify('ok', "Export terminé.");
    }
});

function change_public_marks(e) {
    change_config_value(e);
    update_public_marks(e);
}

function update_public_marks(e) {
    var links = document.getElementById("public-marks-links");
    if(e.checked) links.classList.remove("hidden");
    else links.classList.add("hidden");
}

function tab_grading() {
    show_tab("grading").then(() => {
        u_marks();
        u_identification();
        socket_emit("export-config");
        u_exported_files(null);
        socket_emit("annotation-config");
        u_annotated_files(null);
        socket_emit("association-config");
    });
}

function do_mark() {
    var u = document.getElementById('extract-scale').checked;
    socket_emit("do-mark", u);
}

function change_lkey(e, fixed) {
    if(fixed) {
        var  new_value = e.value;
        e.value = fixed;
        confirm_msg('confirm.lkey', [],
                    'yes:warning', 'cancel:neutral',
                    'socket_emit', ["change-lkey", [new_value, true]]);
    } else {
        socket_emit("change-lkey", [e.value, false]);
    }
}

function change_acode(e) {
    socket_emit("change-acode", e.value);
}

function association_auto() {
    socket_emit("association-auto");
}

function update_students_list() {
    fetch_to_dom("students-list", "/students_list.html", {});
}

socket.on("update-students-list", update_students_list);

function grading_switch_update(view) {
    var a = document.getElementById("view-results");
    var b = document.getElementById("view-assoc");
    if(a) a.classList.toggle("current", view == "results");
    if(b) b.classList.toggle("current", view == "assoc");
}

function association_manual() {
    grading_switch_update("assoc");
    document.getElementById("grading").classList.add("hidden");
    document.getElementById("association").classList.remove("hidden");
    clear_select_student(null);
    fetch_to_dom("assoc-sheets", "/assoc_sheets.html", {})
        .then(() => {
            select_assoc_sheet(-1,-1);
            first_not_associated();
        })
        .then(assoc_refresh_all);
    update_students_list();
    namefield_conf = {};
}

function association_manual_done() {
    grading_switch_update("results");
    document.getElementById("association").classList.add("hidden");
    document.getElementById("grading").classList.remove("hidden");
    u_identification();
}

function association_clear() {
    confirm_msg('confirm.rmassociation', [],
                'yes:warning', 'cancel:neutral',
                'socket_emit', ["association-clear"]);
}

var assoc_sheet = [-1,-1];

function student_highlight(id) {
    var e;
    for(e of document.querySelectorAll("#students-list li.student-name")) {
        e.classList.remove("highlight");
    }
    if(id != "None") {
        e = document.querySelector(
            `#students-list li.student-name[amc-id="${id}"]`
        );
        if(e)
            e.classList.add("highlight");
    }
}

function normalize_string(s) {
    return(s.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase());
}

var n_selected_students = -1;
var last_selected_student;

function clear_select_student(entry) {
    if(!entry) entry = document.getElementById("student-entry");
    entry.value = "";
    select_students(entry);
}

function select_students(entry) {
    if(!entry) entry = document.getElementById("student-entry");
    var beginning = document.getElementById("global:filter_beginning").checked;
    var search_strings = normalize_string(entry.value).split(" ");
    var search_regexs;
    if(beginning) {
        search_regexs = search_strings.map((i) => new RegExp("\\b" + i));
    }
    var list = document.getElementById("students-list");
    n_selected_students = 0;
    for(student of list.getElementsByTagName("li")) {
        var selected = true;
        var name = normalize_string(student.textContent);
        if(beginning) {
            for(i of search_regexs) {
                if(! name.match(i)) selected = false ;
            }
        } else {
            for(i of search_strings) {
                if(! name.includes(i)) selected = false ;
            }
        }
        if(selected) {
            student.classList.remove("hidden");
            n_selected_students++;
            last_selected_student = student;
        } else student.classList.add("hidden");
    }
    if(n_selected_students == 0) {
        document.getElementById("create-student").classList.remove("hidden");
        document.getElementById("create-student-surname").value = entry.value;
        document.getElementById("create-student-name").value = "";
        document.getElementById("create-student-id").value = "";
    } else {
        document.getElementById("create-student").classList.add("hidden");
    }
}

function select_students_keyup(entry, event) {
    if(event.key == "Enter" && n_selected_students == 1) {
        select_student_name(last_selected_student);
        return false;
    }
    if(event.key == "Escape") {
        clear_select_student();
        return false;
    }
}

function start_student_entry() {
    var entry = document.getElementById("student-entry");
    clear_select_student(entry);
    entry.focus();
}

function select_assoc_sheet(e, student, copy) {
    if(student >= 0) {
        fetch_to_dom("studentname", `/namefield/${student}/${copy}`, {})
            .then(() => {
                var x;
                for(x of document.querySelectorAll("#assoc-sheets tr"))
                    x.classList.remove("selected");
                e.classList.add("selected");
                var auto = e.getAttribute("amc-auto");
                var manual = e.getAttribute("amc-manual");
                student_highlight(manual == "None" ? auto : manual);
                assoc_confidence_selected(student, copy);
            })
            .then(start_student_entry);
    } else {
        var e = document.getElementById("studentname");
        if(e) {
            e.innerHTML = "";
        }
        student_highlight("None");
    }
    assoc_sheet = [student, copy];
}

function first_not_associated() {
    var e = document.querySelector('#assoc-sheets tr[amc-auto="None"][amc-manual="None"]');
    if(e) {
        select_assoc_sheet(e,
                           parseInt(e.getAttribute("amc-student")),
                           parseInt(e.getAttribute("amc-copy")));
        e.scrollIntoView({block: "center"});
    }
}

function select_student_name(e) {
    var student_id = e.getAttribute("amc-id");
    if(assoc_sheet[0]>=0)
        socket_emit("associate", [...assoc_sheet, student_id]);
}

function set_association_student(student_id, associated) {
    var e = document.querySelector(
        `li.student-name[amc-id="${student_id}"]`
    );
    if(e) {
        if(associated)
            e.classList.add("associated");
        else
            e.classList.remove("associated");
    }
}

function set_association(student, copy, student_id) {
    var e = document.querySelector(
        `#assoc-sheets tbody tr[amc-student="${student}"][amc-copy="${copy}"]`
    );
    if(e) {
        var auto = e.getAttribute("amc-auto");
        var manual = e.getAttribute("amc-manual");
        var old = (manual=="None" ? auto : manual);
        set_association_student(old, false);
        e.setAttribute("amc-manual", student_id);
        set_association_student(student_id, true);
    }
}

function assoc_status_of(tr) {
    var manual = tr.getAttribute("amc-manual");
    var auto = tr.getAttribute("amc-auto");
    if(manual && manual != "None") return "manual";
    if(auto && auto != "None") return "auto";
    return "none";
}

function assoc_update_status(tr) {
    var s = assoc_status_of(tr);
    tr.classList.remove("assoc-manual", "assoc-auto", "assoc-none");
    tr.classList.add("assoc-" + s);
    return s;
}

function assoc_refresh_all() {
    var counts = { auto: 0, manual: 0, none: 0 };
    for(var tr of document.querySelectorAll("#assoc-sheets tbody tr")) {
        counts[assoc_update_status(tr)]++;
    }
    counts.all = counts.auto + counts.manual + counts.none;
    for(var chip of document.querySelectorAll("#assoc-filter .fchip")) {
        var fc = chip.querySelector(".fc");
        if(fc) fc.textContent = counts[chip.getAttribute("data-status")];
    }
    assoc_apply_cached_conf();
}

function filter_assoc(chip) {
    for(var c of document.querySelectorAll("#assoc-filter .fchip")) c.classList.remove("current");
    chip.classList.add("current");
    var status = chip.getAttribute("data-status");
    for(var tr of document.querySelectorAll("#assoc-sheets tbody tr")) {
        tr.style.display = (status == "all" || assoc_status_of(tr) == status) ? "" : "none";
    }
}

function reapply_assoc_filter() {
    var c = document.querySelector("#assoc-filter .fchip.current");
    if(c) filter_assoc(c);
}

// ----------------------- CONFIANCE (proxy)

// ponytail: proxie de confiance — compare le texte détecté du champ nom
// (uniquement disponible quand le champ est textuel) au nom de l'élève
// associé. Aucun score n'existe côté serveur ; ce n'est pas un score AMC.
var namefield_conf = {};

function levenshtein(a, b) {
    var m = a.length, n = b.length;
    if(!m) return n;
    if(!n) return m;
    var prev = new Array(n + 1), cur = new Array(n + 1);
    for(var j = 0; j <= n; j++) prev[j] = j;
    for(var i = 1; i <= m; i++) {
        cur[0] = i;
        for(var k = 1; k <= n; k++) {
            var cost = (a[i - 1] == b[k - 1]) ? 0 : 1;
            cur[k] = Math.min(prev[k] + 1, cur[k - 1] + 1, prev[k - 1] + cost);
        }
        var t = prev; prev = cur; cur = t;
    }
    return prev[n];
}

function clean_name(s) {
    return normalize_string(s || "").replace(/[^a-z0-9 ]/g, " ").replace(/\s+/g, " ").trim();
}

function name_similarity(a, b) {
    a = clean_name(a); b = clean_name(b);
    if(!a || !b) return 0;
    return 1 - levenshtein(a, b) / Math.max(a.length, b.length);
}

function student_name_by_id(id) {
    var e = document.querySelector('#students-list li.student-name[amc-id="' + id + '"]');
    return e ? e.textContent.trim() : null;
}

function detected_namefield_text() {
    var num = document.querySelector("#studentname .sheetnum div");
    if(!num) return null;
    var t = num.textContent.trim();
    if(!t || /^Sheet\b/.test(t)) return null;
    return t;
}

function set_conf(tr, conf, detected) {
    var el = tr.querySelector(".assoc-conf");
    if(el) {
        if(conf === null || conf === undefined) {
            el.textContent = "";
            el.className = "assoc-conf";
        } else {
            el.textContent = conf + " %";
            el.className = "assoc-conf " + (conf >= 90 ? "hi" : (conf >= 70 ? "mid" : "lo"));
        }
        if(detected) el.setAttribute("title", "Détecté : " + detected);
        else el.removeAttribute("title");
    }
}

function assoc_confidence_selected(student, copy) {
    if(student < 0) return;
    var detected = detected_namefield_text();
    var tr = document.querySelector(
        `#assoc-sheets tbody tr[amc-student="${student}"][amc-copy="${copy}"]`);
    var manual = tr ? tr.getAttribute("amc-manual") : "None";
    var auto = tr ? tr.getAttribute("amc-auto") : "None";
    var assigned = (manual && manual != "None") ? manual : auto;
    var conf = null;
    if(detected && assigned && assigned != "None") {
        var name = student_name_by_id(assigned);
        if(name) conf = Math.round(100 * name_similarity(detected, name));
    }
    namefield_conf[student + "-" + copy] = { conf: conf, detected: detected };
    if(tr) set_conf(tr, conf, detected);
    var cb = document.getElementById("studentname-conf");
    if(cb) {
        if(conf === null || conf === undefined) {
            cb.classList.add("hidden");
        } else {
            cb.classList.remove("hidden");
            cb.className = "conf-badge " + (conf >= 90 ? "hi" : (conf >= 70 ? "mid" : "lo"));
            cb.textContent = "Correspondance " + conf + " %";
        }
    }
}

function assoc_apply_cached_conf() {
    for(var tr of document.querySelectorAll("#assoc-sheets tbody tr")) {
        var k = tr.getAttribute("amc-student") + "-" + tr.getAttribute("amc-copy");
        var v = namefield_conf[k];
        if(v) set_conf(tr, v.conf, v.detected);
    }
}

function student_id_test_row(element, event) {
    var string = (event.clipboardData || window.clipboardData).getData("text");
    var row = string.split(/\s*[,;\t\n\r]+\s*/);
    console.log(row);
    if(row.length > 1) {
        element.value = row[0];
        document.getElementById("create-student-surname").value = row[1];
        if(row.length > 2)
            document.getElementById("create-student-name").value = row[2];
        event.preventDefault();
    }
}

function create_student() {
    var id = document.getElementById("create-student-id").value.trim();
    var name = document.getElementById("create-student-name").value.trim();
    var surname = document.getElementById("create-student-surname").value.trim();
    if(id && surname && assoc_sheet[0]>=0) {
        socket_emit("associate-new", [id, surname, name, ...assoc_sheet]);
    }
}

socket.on("update-association", function(data) {
    var student = data[0];
    var copy = data[1];
    var student_id = data[2];
    var to_rm = data[3];
    
    for(sc of to_rm) {
        set_association(sc[0], sc[1], "");
    }
    set_association(student, copy, student_id);
    if(student == assoc_sheet[0]
       && copy == assoc_sheet[1]) {
        student_highlight(student_id);
    }
    first_not_associated();
    assoc_refresh_all();
    reapply_assoc_filter();
    if(student == assoc_sheet[0] && copy == assoc_sheet[1])
        assoc_confidence_selected(student, copy);
});

function change_export_module(e) {
    if(!e) e = document.getElementById("format_export");
    change_config_value(e);
    update_export_module(e);
}

function update_export_module(e) {
    if(!e) e = document.getElementById("format_export");
    var module = e.value;
    for(const m of ["ods", "CSV"]) {
        var x = document.getElementById("export-" + m);
        if(m == module) x.classList.remove("hidden");
        else x.classList.add("hidden");
    }
}

function range_to_config(range, id) {
    var n = document.getElementById(id);
    if(n) {
        n.value = range.value;
        change_config_value(n);
    }
}

function change_config_value(e) {
    var value;
    if(e.type == "checkbox")
        value = (e.checked ? "1" : "");
    else if(e.type == "select-one"
            || e.type == "text"
            || e.type == "number"
            || e.type == "textarea")
        value = e.value;
    else {
        console.log("Unknown type: " + e.type);
        return;
    }
    socket_emit("set-config", [e.getAttribute("id"), value]);
}

socket.on("selected-config", function(data) {
    for(var k in data) {
        var e = document.getElementById(k);
        if(e) {
            if(e.type == "checkbox")
                e.checked = Boolean(data[k]);
            else if(e.type == "select-one"
                    || e.type == "text"
                    || e.type == "number")
                e.value = data[k];
            else if(e.type == "textarea")
                e.textContent = data[k];
            else
                console.log("Unknown type: " + e.type);
            if(!e.getAttribute("onchange"))
                e.setAttribute("onchange", "change_config_value(this);");

            var r = document.querySelector('[data-range-for="' + k + '"]');
            if(r) r.value = data[k];

            if(k=="format_export") update_export_module(e);
            if(k=="app_public_marks") update_public_marks(e);
        }
    }
});

function flash_files(e) {
    setTimeout(()=>{
        var x = e.getElementsByClassName("files");
        if(x) {
            var panel = x[0];
            var color = "#f5f542";
            var y = panel.getElementsByClassName("recent");
            if(!y.length) color="#f55e42";
            var orig_color = panel.style.backgroundColor;
            panel.style.transition = "none";
            panel.style.backgroundColor = color;
            setTimeout(()=>{
                panel.style.transition = "background-color 1.5s linear";
                panel.style.backgroundColor = orig_color; },
                       1500);
        } else {
            console.log("Flash files not found…");
        }
    });
}

function do_export() {
    socket_emit("do-export");
}

function do_annotate() {
    socket_emit("do-annotate");
}

function u_annotated_files(t) {
    fetch_to_dom("annotated-files", "/annotated_files.html",
                 {
                     method: "POST",
                     headers: {
                         'Content-Type': 'application/json'
                     },
                     body: JSON.stringify({ t: t})
                 })
        .then( () => {
            if(t) flash_files(document.getElementById("annotated-files"));
        });
}
socket.on("update-annotated-files", u_annotated_files);
socket.on("update-annotated-files", function(t) {
    if(t) notify('ok', "Copies annotées générées.");
});

// ----------------------- keys

function key_up(event) {
    if(event.target.id == "app-body") {
        if(current_tab == "scans") {
            if(event.code == "PageUp") scans_page_move_up();
            if(event.code == "PageDown") scans_page_move_down();
        }
    }
}

// ----------------------- MAIN

document.addEventListener('DOMContentLoaded', function() {
    start_inactivity();
    render_workflow();
    document.getElementById("app-body").addEventListener("keyup", key_up);
    window.addEventListener("beforeunload", function(e) {
        if(source_dirty) {
            e.preventDefault();
            e.returnValue = "";
        }
    });
    document.addEventListener("keydown", function(event) {
        if(event.key == "Escape") {
            var wp = document.getElementById("warn-panel");
            if(wp && !wp.classList.contains("hidden")) warn_ok();
        }
    });
    connection_status(socket.connected ? "online" : "offline");
    if(!socket_creation)
        restore_project();
});

