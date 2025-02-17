let currentUser = null;

function login() {
    const username = document.getElementById("username").value;
    const password = document.getElementById("password").value;

    if (username && password) {
        currentUser = username;
        document.getElementById("loginScreen").style.display = "none";
        document.getElementById("chatScreen").style.display = "flex";

        loadMessages(); 

        setInterval(loadMessages, 500);
    } else {
        alert("Por favor, preencha todos os campos.");
    }
}

function sendMessage(event) {
    if (event.key === "Enter") {
        const message = document.getElementById("messageInput").value;
        if (message) {
            fetch('/send', {
                method: 'POST',
                headers: {
                    'Content-Type': 'text/plain'
                },
                body: message
            })
            .then(response => response.json())
            .then(data => {
                console.log(data); 
                loadMessages(); 
            })
            .catch(error => console.error('Erro ao enviar mensagem:', error));

            document.getElementById("messageInput").value = ""; 
        }
    }
}

function loadMessages() {
    fetch('localhost:6969/messages')
        .then(response => response.json())
        .then(messages => {
            const messagesDiv = document.getElementById("messages");
            messagesDiv.innerHTML = ""; 
            messages.forEach(message => {
                const messageElement = document.createElement("p");
                messageElement.textContent = message;
                messagesDiv.appendChild(messageElement);
            });
        })
        .catch(error => console.error('Erro ao carregar mensagens:', error));
}
