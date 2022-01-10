/* HTTP request */
function request(method, url) {
    return new Promise(function (resolve, reject) {
        let xhr = new XMLHttpRequest();
        xhr.open(method, url);
        xhr.onload = function () {
            if (this.status >= 200 && this.status < 300) {
                resolve(xhr.response);
            } else {
                reject({
                    status: this.status,
                    statusText: xhr.statusText
                });
            }
        };
        xhr.onerror = function () {
            reject({
                status: this.status,
                statusText: xhr.statusText
            });
        };
        xhr.send();
    });
}

/* Lazy-load list single item into unordered list */
function load_element(ul, name, device_url) {
    console.log("Lazy-load list item: " + device_url);
    request("GET", device_url).then(function(html) {
        var li = document.createElement("li");
        li.innerHTML = html;
        li.classList.add("device");
        li.dataset.name = name;
        ul.appendChild(li);
    });
}

/* Lazy-load list items into unordered list with data attribute "fill" */
function load_list(ul_id, list_url) {
    request("GET", list_url).then(function(device_names_urls_str) {
        console.log("List items to lazy-load for " + ul_id + ": " + device_names_urls_str);

        device_names_urls = JSON.parse(device_names_urls_str);

        ul = document.getElementById(ul_id);
        for (var name in device_names_urls) {
            load_element(ul, name, device_names_urls[name] + "?name=" + name);
        }
    });
}

function onload_body() {
    /* Lazy-load all lists with data attribute "fill" */
    var dynamic_elements = document.querySelectorAll('[data-fill]');
    for (const dynamic_element of dynamic_elements) {
        load_list(dynamic_element.id, dynamic_element.dataset.fill);
    }
}



/************************************ pins ************************************/
/* Switch pin and reload device */
function onclick_pin(label) {
    new_pin_state = label.firstElementChild.checked ? "0" : "1";
    device_url = "../html/w1/" + label.dataset.device
    switch_url = "../api/w1/" + label.dataset.device + "/switch?pin=" + label.dataset.pin + "&state=" + new_pin_state;

    request("GET", switch_url).then(function(json) {
        /* refresh device: remove and re-add */
        li = label.parentNode.parentNode.parentNode.parentNode.parentNode
        ul = li.parentNode;
        var name = li.dataset.name;

        load_element(ul, name, device_url + "?name=" + name);
        li.parentNode.removeChild(li);
    });
}