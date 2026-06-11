pragma Singleton
import Quickshell

Singleton {

    function getPath(name) {
        return "file://" + Quickshell.shellDir + "/assets/icons/" + name + ".svg";
    }
}
