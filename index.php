<?php
$message = "";

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    if (isset($_POST["reboot"])) {
        reboot();
    } elseif (isset($_POST["update"])) {
        forceUpdate();
    } elseif (isset($_POST["refresh"])) {
        restartApp();
    } elseif (isset($_POST["version"])) {
        printVersion();
    } elseif (isset($_POST["show"])) {
        printURL();
    }
}
if ($_SERVER["REQUEST_METHOD"] == "POST" && isset($_POST["action"])) {
    $action = $_POST["action"];

    switch ($action) {
    case "update":
        $output = forceUpdate();
        break;
    case "refresh":
        $output = restartApp();
        break;
    case "show":
        $output = printURL();
        break;
    case "version":
        $output = printVersion();
        break;
    case "reboot":
        $output = reboot();
        break;
    default:
        $output = "Invalid action";
    }

    echo $output;
    exit();
}

function reboot()
{
    $output = shell_exec("./startup.sh --reboot --debug");
    return $output;
}

function forceUpdate()
{
    $output = shell_exec("./startup.sh --force-update --debug");
    return $output;
}

function restartApp()
{
    # After the integration of a watch dog, there is no need to call startup.sh
    # with restart-app argument. The watch dog will take care of relaunching
    # the cmonitor application
    $output = shell_exec("./startup.sh  --kill-app --debug");
    return $output;
}

function printVersion()
{
    $output = shell_exec("./startup.sh  --print-version --debug");
    return $output;
}

function printURL()
{
    $output = shell_exec("./startup.sh  --print-url --debug");
    return $output;
}
?>

<!DOCTYPE html>
<html lang="en">

<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <link rel="icon" href="./src/favicon.ico">
    <title>CMonitor - Standalone</title>
    <link rel="stylesheet" href="./src/css/bootstrap.min.css">
    <link rel="stylesheet" href="./src/css/bootstrap-icons-1.11.2/font/bootstrap-icons.css">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Open+Sans:wght@400;700&display=swap">
    <link rel="stylesheet" href="./src/css/toastr.min.css">
    <link rel="stylesheet" href="./src/css/style.css">
    <style>
        .toast {
            opacity: 1 !important;
        }
    </style>
    <script src="./src/js/jquery.min.js"></script>
    <script src="./src/js/popper.min.js"></script>
    <script src="./src/js/bootstrap.min.js"></script>
    <script src="./src/js/toastr.min.js"></script>
    <script>
        function sendRequest(action) {
            if ( action == "update" ) {
                document.getElementById("loading-spinner").style.visibility = "visible";
                document.getElementById("spinner-span").innerHTML = "Update in progress, could take up to 3 minutes";
            } else if ( action == "refresh" ) {
                document.getElementById("loading-spinner").style.visibility = "visible";
                document.getElementById("spinner-span").innerHTML = "Restarting cmonitor application in progress, could take up to 30 seconds";
            }
            toastr.options = {
                "closeButton": false,
                "debug": false,
                "newestOnTop": false,
                "progressBar": false,
                "positionClass": "toast-top-center",
                "preventDuplicates": false,
                "onclick": null,
                "showDuration": "300",
                "hideDuration": "1000",
                "timeOut": "5000",
                "extendedTimeOut": "1000",
                "showEasing": "swing",
                "hideEasing": "linear",
                "showMethod": "fadeIn",
                "hideMethod": "fadeOut",
                "progressBar": "true",
            };
            var xhttp = new XMLHttpRequest();
            xhttp.onreadystatechange = function () {
                var self = this;
                if (self.readyState == 4 && self.status == 200) {
                    document.getElementById("loading-spinner").style.visibility = "hidden";
                    var logSection = document.getElementById("logs-section");
                    var logsContainer = document.getElementById("logs-container");
                    logsContainer.textContent = self.responseText;
                    var createTicketButton = document.getElementById("btn-jira-ticket");
                    createTicketButton.style.visibility = "hidden";
                    // Show warning toastr first
                    if (action == "reboot") {
                        toastr.warning(getWarningMessage(action)).css("width","800px");
                        // After the specified duration, show the success or error toastr
                        var timeoutDuration = 3000;
                        setTimeout(function () {
                            toastr.clear();
                            showResultToastr(self);
                        }, timeoutDuration);
                    } else {
                        showResultToastr(self);
                    }
                    function showResultToastr(self) {
                        if (self.status == 200 && self.responseText.toLowerCase().includes("error")) {
                            logSection.style.borderWidth = "3px";
                            logSection.style.borderStyle = "solid";
                            logSection.style.borderColor = "#ffcccc";
                            toastr.error(getErrorMessage(action));
                            createTicketButton.style.visibility = "visible";
                        } else {
                            logSection.style.borderWidth = "3px";
                            logSection.style.borderStyle = "solid";
                            logSection.style.borderColor = "#ccffcc";
                            if (action == "show"){
                                toastr.success(getSuccessMessage(action)).css("width","800px");
                            }else{
                                toastr.success(getSuccessMessage(action));
                            }
                        }
                    }
                }
            };

            xhttp.open("POST", "", true);
            xhttp.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
            xhttp.send("action=" + action);
        }

        function getWarningMessage(action) {
            if (action == "update") {
                return "Please wait for the update to be completed";
            } else if (action == "reboot") {
                return "Reboot in progress, Please wait until the reboot is completed";
            }
        }

        function getSuccessMessage(action) {
            var logsContainer = document.getElementById("logs-container");
            if (action == "show") {
                var lines = logsContainer.textContent.split('\n');
                var extractedLines = lines.slice(-6).map(removeInfoBlock);
                var combinedLines = extractedLines.join('<br>');
                return combinedLines;
            } else if (action == "version") {
                var lines = logsContainer.textContent.split('\n');
                var lastTwoLines = lines.slice(-3).join('\n');
                lastTwoLines = extractSubstring(lastTwoLines);
                lastTwoLines = lastTwoLines.replace(/\n/g, '</br>');
                return lastTwoLines;
            } else if (action == "reboot") {
                return "Rebooting";
            } else if (action == "refresh") {
                return "Restarting screen ...";
            } else {
                return "Update complete";
            }
        }

        function getErrorMessage(action) {
            if (action == "show") {
                return "Failed to "+ action + "display !";
            } else if (action == "version") {
                return "Failed to show "+ action +"s !";
            } else if (action == "reboot") {
                return "Failed to "+ action;
            } else if (action == "refresh") {
                return "Failed to "+ action +"the screen !";
            } else {
                return "Update failed !";
            }
        }

        function removeInfoBlock(line) {
            // Remove the block [...][info]: from each line
            return line.replace(/\[\d{2}\/\d{2}\/\d{4} \d{2}:\d{2}:\d{2}\.\d+\]\[INFO\]: /, '');
        }

        function extractSubstring(inputString) {
            var extractedSubstrings = [];
            var inputArray = inputString.split("\n");

            for (var i = 0; i < inputArray.length; i++) {
                var startPosition = inputString.indexOf("CMonitor");
                var extractedString = "";

                if (startPosition !== -1) {
                    var extractedString = inputArray[i].substring(startPosition);
                    extractedSubstrings.push(extractedString);
                }
            }
            return extractedSubstrings.join("\n");
        }

        function createJiraTicket() {
            var logsContainer = document.getElementById("logs-container");
            var logsContent = logsContainer.textContent|| logsContainer.innerText;
            console.log(logsContent);
            var createTicketButton = document.getElementById("btn-jira-ticket");
            var xhttp = new XMLHttpRequest();
            window.location.href = "https://jira.cdiscount.com/secure/CreateIssueDetails!init.jspa?pid=27702&issuetype=10703";

            xhttp.onreadystatechange = function() {
                if (this.readyState == 4) {
                    if (this.status == 201) {
                        toastr.success("Jira ticket created successfully!");
                        createTicketButton.style.visibility = "hidden";
                    } else {
                        toastr.error("Failed to create Jira ticket!");
                    }
                }
            };
        }

        function extractSubstring(inputString) {
            var extractedSubstrings = [];
            var inputArray = inputString.split("\n");

            for (var i = 0; i < inputArray.length; i++) {
                var startPosition = inputString.indexOf("CMonitor");
                var extractedString = "";

                if (startPosition !== -1) {
                    var extractedString = inputArray[i].substring(startPosition);
                    extractedSubstrings.push(extractedString);
                }
            }
            return extractedSubstrings.join("\n");
        }

        function removeInfoBlock(line) {
            // Remove the block [...][info]: from each line
            return line.replace(/\[\d{2}\/\d{2}\/\d{4} \d{2}:\d{2}:\d{2}\.\d+\]\[INFO\]: /, '');
        }
    </script>
</head>

<body>
    <div class="container">
        <div class="row">
            <div class="col-12 text-center pb-5">
                <h1>CMonitor</h1>
            </div>
            <div class="col-12 text-center mb-4" style="visibility:hidden;" id="loading-spinner">
                <div>
                    <span class="spinner-border spinner-border-sm" aria-hidden="true" style="color:orange; font-family: 'Open Sans', sans-serif;"></span>
                    <span id="spinner-span" role="status" style="color:orange;"></span>
                 </div>
            </div>
            <div class="col-12">
                <form method="POST" class="form">
                    <div class="col-12 pb-5">
                        <h1 class="h3 mb-3 font-weight-normal text-center">
                            <span>
                                <?php echo gethostname(); ?>
                            </span>
                            <small class="text-muted">
                            <a href='startup-log.txt' target='_blank'>log</a>
                            </small>
                            <small class="text-muted">Managed by <a href='https://cmonitor.cdbdx.biz' target='_blank'>CMonitor</a>
                            </small>
                        </h1>
                    </div>
                    <div class="col-12 d-flex justify-content-center mb-4">
                        <div>
                            <button type="button" class="btn btn-lg btn-outline-secondary mx-2" name="update" id="update" onclick="sendRequest('update')">
                                <i class="bi bi-layout-text-sidebar-reverse"></i>
                                Update
                            </button>
                        </div>
                        <div>
                            <button type="button" class="btn btn-lg btn-outline-secondary mx-2" name="refresh" id="refresh" onclick="sendRequest('refresh')">
                                <i class="bi bi-arrow-clockwise"></i>
                                Refresh
                            </button>
                        </div>
                        <div>
                            <button type="button" class="btn btn-lg btn-outline-secondary mx-2" name="show" id="show" onclick="sendRequest('show')" >
                                <i class="bi bi-tv"></i>
                                Show display
                            </button>
                        </div>
                        <div>
                            <button type="button" class="btn btn-lg btn-outline-secondary mx-2" name="version" id="version" onclick="sendRequest('version')">
                                <i class="bi bi-info-circle"></i>
                                Show version
                            </button>
                        </div>
                        <div>
                            <button type="button" class="btn btn-lg btn-outline-secondary mx-2" name="reboot" id="reboot" onclick="sendRequest('reboot')">
                                <i class="bi bi-bootstrap-reboot"></i>
                                Reboot
                            </button>
                        </div>
                        <div>
                            <button type="button" class="btn btn-lg btn-outline-secondary mx-2" type="button" data-bs-toggle="collapse" data-bs-target="#collapseExample" aria-expanded="false" aria-controls="collapseExample">
                                <i class="bi bi-aspect-ratio"></i>
                                Show Logs
                            </button>
                        </div>
                    </div>
                    <div class="collapse" id="collapseExample">
                        <div class="logs-section" id="logs-section">
                            <pre class="logs-container" id="logs-container">
                                <?php echo $message; ?>
                            </pre>
                            <button type="button" class="btn btn-sm btn-outline-secondary mx-2" id="btn-jira-ticket" onclick="createJiraTicket()">
                                <i class="bi bi-file-earmark-plus"></i>
                                Create Jira Ticket
                            </button>
                        </div>
                    </div>
                </form>
            </div>
        </div>
    </div>
</body>

</html>
