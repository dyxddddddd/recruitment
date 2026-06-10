import webSocket from '@ohos.net.webSocket'
import { BusinessError } from '@kit.BasicServicesKit'

const TAG = 'StompClient'

export interface StompMessage {
  destination: string
  body: string
}

interface WsConnectOptions {
  header: Record<string, string>
}

export class StompClient {
  private ws: webSocket.WebSocket | null = null
  private url: string
  private userId: string
  private connected: boolean = false
  private messageCallback: ((msg: StompMessage) => void) | null = null
  private closeCallback: (() => void) | null = null
  private subscriptionId: number = 0
  private buffer: string = ''
  private reconnectTimer: number = -1
  private reconnectAttempts: number = 0
  private maxReconnectAttempts: number = 10
  private heartbeatTimer: number = -1

  constructor(url: string, userId: string) {
    this.url = url
    this.userId = userId
  }

  connect(): void {
    try {
      this.ws = webSocket.createWebSocket()
      this.ws.on('message', (err: BusinessError, value: string | ArrayBuffer) => {
        if (!err && typeof value === 'string') {
          this.handleData(value)
        }
      })
      this.ws.on('close', (err: BusinessError) => {
        this.connected = false
        this.stopHeartbeat()
        if (this.closeCallback) {
          this.closeCallback()
        }
        this.tryReconnect()
      })
      this.ws.on('error', (err: BusinessError) => {
        this.connected = false
      })

      const connectOptions: WsConnectOptions = {
        header: { 'User-Agent': 'HarmonyOS-IM' }
      }
      this.ws.connect(this.url, connectOptions, (err: BusinessError) => {
        if (!err) {
          this.sendStompFrame('CONNECT', {
            'accept-version': '1.2',
            'host': 'localhost',
            'userId': this.userId,
            'heart-beat': '10000,10000'
          })
        }
      })
    } catch (e) {
      this.tryReconnect()
    }
  }

  onMessage(callback: (msg: StompMessage) => void): void {
    this.messageCallback = callback
  }

  onClose(callback: () => void): void {
    this.closeCallback = callback
  }

  subscribe(destination: string): string {
    const id = `sub-${++this.subscriptionId}`
    this.sendStompFrame('SUBSCRIBE', {
      'id': id,
      'destination': destination,
      'ack': 'auto'
    })
    return id
  }

  send(destination: string, body: string): void {
    this.sendStompFrame('SEND', {
      'destination': destination,
      'content-type': 'application/json'
    }, body)
  }

  disconnect(): void {
    this.stopReconnect()
    this.stopHeartbeat()
    if (this.connected && this.ws) {
      this.sendRawFrame('DISCONNECT\n\n\0')
      this.ws.close()
    }
    this.connected = false
  }

  isConnected(): boolean {
    return this.connected
  }

  private handleData(data: string): void {
    this.buffer += data
    while (this.buffer.includes('\0')) {
      const nullIndex = this.buffer.indexOf('\0')
      const frame = this.buffer.substring(0, nullIndex)
      this.buffer = this.buffer.substring(nullIndex + 1)
      if (frame.trim()) {
        this.processFrame(frame)
      }
    }
  }

  private processFrame(frame: string): void {
    const lines = frame.split('\n')
    if (lines.length === 0) {
      return
    }

    const command = lines[0].trim()
    const headers: Record<string, string> = {}
    let bodyStart = 1
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i]
      if (line === '') {
        bodyStart = i + 1
        break
      }
      const colonIndex = line.indexOf(':')
      if (colonIndex > 0) {
        headers[line.substring(0, colonIndex).trim()] = line.substring(colonIndex + 1).trim()
      }
    }
    const body = lines.slice(bodyStart).join('\n').trim()

    switch (command) {
      case 'CONNECTED':
        this.connected = true
        this.reconnectAttempts = 0
        this.startHeartbeat()
        if (this.messageCallback) {
          this.messageCallback({
            destination: '__connected__',
            body: JSON.stringify(headers)
          })
        }
        break
      case 'MESSAGE':
        if (this.messageCallback) {
          this.messageCallback({
            destination: headers['destination'] || '',
            body: body
          })
        }
        break
      case 'RECEIPT':
        break
      case 'ERROR':
        break
    }
  }

  private sendStompFrame(command: string, headers: Record<string, string>, body?: string): void {
    let frame = command + '\n'
    const keys = Object.keys(headers)
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i]
      frame += `${key}:${headers[key]}\n`
    }
    frame += '\n'
    if (body) {
      frame += body
    }
    frame += '\0'
    this.sendRawFrame(frame)
  }

  private sendRawFrame(frame: string): void {
    if (this.ws) {
      try {
        this.ws.send(frame, (err: BusinessError) => {
          if (err) {
            // send failed
          }
        })
      } catch (e) {
        // ignore
      }
    }
  }

  private startHeartbeat(): void {
    this.stopHeartbeat()
    this.heartbeatTimer = setInterval(() => {
      this.sendRawFrame('\n')
    }, 8000)
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer !== -1) {
      clearInterval(this.heartbeatTimer)
      this.heartbeatTimer = -1
    }
  }

  private tryReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      return
    }
    this.reconnectAttempts++
    const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000)
    this.reconnectTimer = setTimeout(() => {
      this.connect()
    }, delay)
  }

  private stopReconnect(): void {
    if (this.reconnectTimer !== -1) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = -1
    }
  }
}
