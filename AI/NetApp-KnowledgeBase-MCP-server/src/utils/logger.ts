import log4js from 'log4js';

log4js.configure({
    appenders: {
        server: {type: "file", filename: "logs/server.log"},
        console: {
            type: "console"
        }
    },
    categories: {default: {appenders: ["server", "console"], level: "info"}},
})

export  function getLogger(){
    return log4js.getLogger('default');
}