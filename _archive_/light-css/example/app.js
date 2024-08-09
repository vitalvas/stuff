(function(){
    "use stricts";
    var rows = 10, cels = 12;
    var table = document.createElement("table");
    var thead = table.createTHead();
    var tbody = table.createTBody();
    var hrow = thead.insertRow(0);
    for (var c=0; c<=cels; c++) {
        var cel = hrow.insertCell(c);
        if (c == 0) {
            cel.innerHTML = "#";
        } else {
            cel.innerHTML = "TH-" + c;
        }
    }
    var classes = ['success', 'info', 'warning', 'danger'];
    for (var i=0; i<rows; i++) {
        var row = tbody.insertRow(i);
        if (classes.length > i) {
            row.className = classes[i];
        }
        for (var c=0; c<=cels; c++) {
            var cel = row.insertCell(c);
            if (c == 0) {
                cel.innerHTML = i;
            } else {
                cel.innerHTML = Math.floor(Math.random(1,99999)*1000);
            }
        }
    }
    document.body.appendChild(table);
})();
