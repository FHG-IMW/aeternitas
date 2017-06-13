// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require ./jquery-3.2.1.min
//= require ./moment.min
//= require ./Chart.min
//= require ./datatables.min
//= require_self
//

window.charts = [];
window.currentTimeRange = {
    from: moment().subtract(30,"minutes"),
    to: moment()
};

function register_chart(cnt, url, chart_options) {
    chart_data = {
        container: $('#'+cnt),
        url: url,
        options: chart_options,
        requests: 0
    };
    window.charts.push(chart_data);
    init_chart(chart_data)
}

function refresh_charts() {
    for(var i=0; i < window.charts.length; i++) {
        var chart_data = window.charts[i];
        chart_data["chart"].destroy();
        init_chart(chart_data)
    }
}

function init_chart(chart_data) {
    if(chart_data["request"]) {
        chart_data["request"].abort();
    } else {
        chart_data["container"].before('<div class="loading"></div>');
    }

    fetch_chart_data(
        chart_data,
        function(data) {
            chart_data["container"].prev().remove();

            var chart = new Chart(
                chart_data["container"].get(0),
                Object.assign({}, chart_data["options"], {data: data})
            );

            chart_data["chart"] = chart;
        },
        function(error) {
            chart_data["container"].prev().remove();
            chart_data["container"].replaceWith('<div class="toast toast-error"> Error loading chart data </div>')
        }
    );
}

function fetch_chart_data(chart_data, on_success, on_failure) {
    chart_data["request"] = $.get(
        chart_data["url"],
        {
            from: window.currentTimeRange["from"].utc().format(),
            to: window.currentTimeRange["to"].utc().format()
        },
        function(data) {
            chart_data["request"] = null;
            on_success(data);
        },
        "JSON"
    ).fail(function(data) {
        if (data.statusText ==='abort') {
            return;
        }
        chart_data["request"] = null;
        on_failure(data);
    });
}

//timepicker
$(document).ready(function() {


    $(".timepicker-header").on("click", function() {
       var header = $(this);
       var body = header.next(".timepicker-body");

       if(body.hasClass("closed")) {
           body.removeClass("closed");
           body.addClass("open");

           var header_pos = header.position();
           var x= header_pos.left - body.outerWidth() + header.outerWidth();
           var y = header_pos.top + header.outerHeight();

           body.css({
               top: y,
               left: x
           });
       } else {
           body.removeClass("open");
           body.addClass("closed");
       }
    });

    $(".timepicker-body .step-item").on("click", function() {
        var item = $(this);
        item.siblings(".step-item").removeClass("active");
        item.addClass("active");

        var offset_minutes = parseInt(item.data("range"));
        window.currentTimeRange["from"] = moment().subtract(offset_minutes, "minutes");
        window.currentTimeRange["to"] = moment();

        item.closest(".timepicker-body")
            .removeClass("open")
            .addClass("closed");

        item.closest(".timepicker").find(".timepicker-header strong").html(item.find("a").html());

        refresh_charts();
    });
});