pragma Singleton
import Quickshell

import qs.src.services

Singleton {

    function getPath(name) {
        return "file://" + Config.iconDirectory + "/" + name + ".svg";
    }
}
