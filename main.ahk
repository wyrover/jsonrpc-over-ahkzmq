#Noenv
#persistent

SetBatchLines -1

SetWorkingDir, "%A_ScriptDir%"
#Include JSON.ahk
#Include LibCon.ahk

global hwnd_main := 0
global WM_NULL := 0x0000
global lp_process_ui_callback := RegisterCallback("process_ui_callback")
global lp_recevie_message := RegisterCallback("recevie_message")
global hThread := 0
global msg
global exit_flag := 0

global dealer
global jsonrpc_client

SmartStartConsole()

recevie_message() {

    zmq := new ZeroMQ

    context := zmq.context()
    dealer := context.socket(zmq.DEALER)

    ; dealer.setsockopt_string(zmq.CURVE_SERVERKEY, "HIm0q5eoJ}Ur7-&prX?y{%wiI3L)I8>ge%sE}l/k", "utf-8")
    ; dealer.setsockopt_string(zmq.CURVE_PUBLICKEY, "YHtx0zuc(ZkWoXaozP*JP+Kg<!#Dt.2S>oNUXn?Y", "utf-8")
    ; dealer.setsockopt_string(zmq.CURVE_SECRETKEY, "{r]PaKZ%WD.q$VAk=E5jMeFkMkSep.Lk]voT/db+", "utf-8")

    dealer.connect("tcp://192.168.79.129:5003")

    jsonrpc_client := new JSONRPCClient(dealer)

    poller := zmq.poller([[dealer, zmq.POLLIN]])

    loop
    {

        if (exit_flag == 1)
            break

        socks := poller.poll()

        if (socks[1]) {

            msg := dealer.recv_string(zmq.DONTWAIT, "utf-8", false)
            if (msg is integer && msg < 0) {
                if (dealer.errno() == zmq.EAGAIN)
                    continue
                if (dealer.errno() == zmq.EINTR)
                    continue
            }

            SendMessage, WM_NULL, Object(msg), lp_process_ui_callback, , ahk_id %hwnd_main%

        }

    }

}

process_ui_callback(object_address)
{

    msg := Object(object_address)

    loop % msg.Length() {

        parsed := JSON.Load(msg[A_Index])
        reply := jsonrpc_client.replies[parsed.id]
        reply.callback.Call(parsed)
        jsonrpc_client.replies.Remove(parsed.id)
    }

    ObjRelease(object_address)

}

Gui, +AlwaysOnTop +hWndhwnd_main
Gui, Add, Text, w1200 vTestText,

Gui, Add, Button, gCallJsonrpc, call jsonrpc
Gui, Add, Button, gGoButton, Exit
Gui, Show, w1200 h100, JsonRPC Over ahkzmp

OnMessage(WM_NULL, "ON_WM_NULL")

GoSub, Start

return

ON_WM_NULL(wParam, lParam)
{
    if (lParam != 0 && wParam != 0) {

        DllCall(lParam, "Ptr", wParam)

    }

}

Start:
    if (!hThread)
        hThread := DllCall("CreateThread", Ptr, 0, Ptr, 0, Ptr, lp_recevie_message, Ptr, 0, UInt, 0, Ptr, 0)

return

CallJsonrpc:

    loop, 100 {
        puts("-------------------------------------------")
        reply := jsonrpc_client.Send("hello", [42, 23], Func("test1"))
        ; 必须 Sleep，发送太快会崩
        Sleep, 10
    }

return

test1(result) {

    puts("reveice jsonrpc result")
    puts(JSON.Dump(result))
}

GoButton:
    exit_flag := 1
    DllCall("WaitForSingleObject", "PTR", hThread, "UInt", 0xFFFFFFFF)
    DllCall("CloseHandle", "PTR", hThread)

    DllCall("DeleteCriticalSection","Ptr", RTL_CRITICAL_SECTION)

ExitApp
return

#Include %A_LineFile%\..\ZeroMQ\ZeroMQ.ahk

class Reply
{
    __New(messageid, body, callback) {
        this.messageid := messageid
        this.body := body
        this.callback := callback
    }

}

class JSONRPCClient
{
    __New(sock) {
        this.sock := sock
        this.replies := {}
        this.uniqueid := 0

    }

    Send(method, params, callback) {

        parsed := JSON.Load("{}")
        parsed.jsonrpc := "2.0"
        parsed.id := ++this.uniqueid
        parsed.method := method
        parsed.params := params

        payload := JSON.Dump(parsed)

        reply := new Reply(parsed.id, payload, callback)
        this.replies.Insert(parsed.id, reply)

        puts(payload)

        loop {
            rc := this.sock.send_string(payload, ZMQ.SNDMORE, "utf-8")
            if (ret is integer && ret < 0) {
                if (this.sock.errno() == ZMQ.EINTR)
                    continue
            }
            puts(this.sock.errno())
            break
        }

        return reply
    }
}

