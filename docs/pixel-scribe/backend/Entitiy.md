- Room
	- has chat room
	- can share screen
	- can do video 
	- MVP single room
	- interact through single web socket
	- video sharing is done through WebRTC
- User
	- no auth
	- has username
	- username is bound to browser storage or cookie
- Chat Room
	- interact through ws



MVP
- Room Registry
	- getRoom
- User Registry
	- getUser
- Room actor
	- Message
		- Join
		- Leave
		- Say
- Web Service
	- / - for index.html
	- /ws/{username} - websocket connection with username
		- WS messages
			- 
	- /user - POST - set username
	- Message
		- SendMessage
		- Disconnect

Supervisor
- Room Factory
- UserRegistry
- RoomRegistry
- WebService