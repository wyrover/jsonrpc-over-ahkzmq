#Noenv
#persistent

SetBatchLines -1

SetWorkingDir, "%A_ScriptDir%"
#Include JSON.ahk
#Include LibCon.ahk

global hwnd_main := 0
global jsonrpc_client := new JSONRPCClient()
global send_message_queue := []

SmartStartConsole()

start() {

    zmq := new ZeroMQ

    context := zmq.context()
    dealer := context.socket(zmq.DEALER)

    ; dealer.setsockopt_string(zmq.CURVE_SERVERKEY, "HIm0q5eoJ}Ur7-&prX?y{%wiI3L)I8>ge%sE}l/k", "utf-8")
    ; dealer.setsockopt_string(zmq.CURVE_PUBLICKEY, "YHtx0zuc(ZkWoXaozP*JP+Kg<!#Dt.2S>oNUXn?Y", "utf-8")
    ; dealer.setsockopt_string(zmq.CURVE_SECRETKEY, "{r]PaKZ%WD.q$VAk=E5jMeFkMkSep.Lk]voT/db+", "utf-8")

    dealer.connect("tcp://192.168.79.129:5004")
    
    poller := zmq.poller([[dealer, zmq.POLLIN | zmq.POLLOUT]])

    loop
    {

        nin := poller.poll(events, 100)

        if (!nin) {
            continue
        }

        if (events[1] & zmq.POLLIN == zmq.POLLIN) {

            msg := dealer.recv_string(zmq.DONTWAIT, "utf-8", false)
            if (msg is integer && msg < 0) {
                if (dealer.errno() == zmq.EAGAIN)
                    continue
                if (dealer.errno() == zmq.EINTR)
                    continue
            }

            loop % msg.Length() {

                parsed := JSON.Load(msg[A_Index])
                key := "jsonrpc_" . parsed.id

                reply_ptr := jsonrpc_client.replies[key]
                reply := Object(reply_ptr)
                if (replay.callback != 0)
                    reply.callback.Call(parsed)
                jsonrpc_client.replies.Remove(key)
                ObjRelease(reply_ptr)
            }

        }

        if (events[1] & zmq.POLLOUT == zmq.POLLOUT) {

            if (send_message_queue.Length() > 0) {
                payload := send_message_queue.RemoveAt(1)

                dealer.send_string(payload, ZMQ.DONTWAIT, "utf-8")
            }

        }

    }

}

Gui, +AlwaysOnTop +hWndhwnd_main
Gui, Add, Text, w1200 vTestText,

Gui, Add, Button, gCallJsonrpc, call jsonrpc
Gui, Add, Button, gGoButton, Exit
Gui, Show, w1200 h100, JsonRPC Over ahkzmp

start()

return

CallJsonrpc:

    ; 大于10w 就大于 jsonrpc 自增 id 65535
    loop, 1000 {
        reply_ptr := jsonrpc_client.Send("hello", [42, 23])
        ; 绑定一个回调方法
        Object(reply_ptr).callback := Func("test1")
        
    }

return

test1(result) {

    puts("reveice jsonrpc result")
    puts(JSON.Dump(result))
}

GoButton:

ExitApp
return

#Include %A_LineFile%\..\ZeroMQ\ZeroMQ.ahk

class Reply
{
    __New(messageid, body, callback := 0) {
        this.messageid := messageid
        this.body := body
        this.callback := callback
    }

}

class JSONRPCClient
{
    __New() {

        this.replies := {}
        this.uniqueid := 0

    }

    Send(method, params) {

        parsed := JSON.Load("{}")
        parsed.jsonrpc := "2.0"
        ;parsed.id := ++this.uniqueid
        parsed.id := uuid()
        parsed.method := method
        parsed.params := params

        payload := JSON.Dump(parsed)

        reply := new Reply(parsed.id, payload)
        reply_ptr := &reply
        key := "jsonrpc_" . parsed.id
        this.replies.Insert(key, reply_ptr)
        ObjAddRef(reply_ptr)

        puts(payload)

        send_message_queue.Push(payload)      

        
        
        return reply_ptr
    }
}

uuid(c = false) {
    static n = 0, l, i
    f := A_FormatInteger, t := A_Now, s := "-"
    SetFormat, Integer, H
    t -= 1970, s
    t := (t . A_MSec) * 10000 + 122192928000000000
    If !i and c {
        Loop, HKLM, System\MountedDevices
            If i := A_LoopRegName
                Break
        StringGetPos, c, i, %s%, R2
        StringMid, i, i, c + 2, 17
    } Else {
        Random, x, 0x100, 0xfff
        Random, y, 0x10000, 0xfffff
        Random, z, 0x100000, 0xffffff
        x := 9 . SubStr(x, 3) . s . 1 . SubStr(y, 3) . SubStr(z, 3)
    } t += n += l = A_Now, l := A_Now
    SetFormat, Integer, %f%
    Return, SubStr(t, 10) . s . SubStr(t, 6, 4) . s . 1 . SubStr(t, 3, 3) . s . (c ? i : x)
}