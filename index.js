window.addEventListener('load', function() {
    fetch('inventory.json')
        .then(resp => resp.json())
        .then(data => {
            let tbody = document.getElementById('inventory');

            data.forEach(item => {
                let tr = document.createElement('tr');

                let qtyTd = document.createElement('td');
                qtyTd.innerHTML = item.amount;

                let maxTd = document.createElement('td');
                if (item.max == -1) {
                    maxTd.innerHTML = '∞';
                } else {
                    maxTd.innerHTML = item.max;
                }

                let nameTd = document.createElement('td');
                nameTd.innerHTML = item.name;

                tr.appendChild(qtyTd);
                tr.appendChild(maxTd);
                tr.appendChild(nameTd);

                if (item.hours <= 24) {
                    tr.className = 'table-danger';
                } else if (item.hours <= 72) {
                    tr.className = 'table-warning';
                } else if (item.hours <= 168) {
                    tr.className = 'table-success';
                } else {
                    tr.className = 'table-info';
                }

                tbody.appendChild(tr);
            });
        });
});
