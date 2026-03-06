import Foundation

enum AppConfig {
    static let apiBaseURL = "http://localhost:3000/api/v1"
    
    static let personalityQuestions: [PersonalityQuestion] = [
            PersonalityQuestion(
                question: "On a Friday night after a long and tiring work week, I prefer to...",
                options: [
                    PersonalityOption(id: "A", letter: "A", text: "Relax and unwind at home with my favorite meal and a good book or movie"),
                    PersonalityOption(id: "B",letter: "B", text: "Try a new restaurant for dinner with a friend and then catch a movie"),
                    PersonalityOption(id: "C",letter: "C", text: "Go to the local bar with my friend group and watch the live music"),
                    PersonalityOption(id: "D",letter: "D", text: "Get dressed up and go out partying with whoever I meet along the way"),
                ]
            ),
            PersonalityQuestion(
                question: "At a party I like to...",
                options: [
                    PersonalityOption(id: "A",letter: "A", text: "Keep to myself, parties aren’t really my thing"),
                    PersonalityOption(id: "B",letter: "B", text: "Find people I already know and chat with them or jump in on an interesting conservation"),
                    PersonalityOption(id: "C",letter: "C", text: "Go up to strangers and make new friends, while I tell them about my latest passion project"),
                    PersonalityOption(id: "D",letter: "D", text: "Have fun and charge my social battery!"),
                ]
            ),
            PersonalityQuestion(
                question: "I like to stay in touch with people by...",
                options: [
                    PersonalityOption(id: "A",letter: "A", text: "Texting, mostly"),
                    PersonalityOption(id: "B",letter: "B", text: "Meeting up with them occasionally to grab coffee"),
                    PersonalityOption(id: "C",letter: "C", text: "Calling them regularly to catch up and sometimes vent"),
                    PersonalityOption(id: "D",letter: "D", text: "Going on spontaneous adventures with them every once in a while"),
                ]
            ),
            PersonalityQuestion(
                question: "My love language is...",
                options: [
                    PersonalityOption(id: "A",letter: "A", text: "Doing acts of service that my loved ones will appreciate"),
                    PersonalityOption(id: "B",letter: "B", text: "Spending quality time with those I love."),
                    PersonalityOption(id: "C",letter: "C", text: "Paying people sincere compliments or words of affirmation"),
                    PersonalityOption(id: "D",letter: "D", text: "Physical touch"),
                ]
            ),
            PersonalityQuestion(
                question: "I handle conflict by...",
                options: [
                    PersonalityOption(id: "A",letter: "A", text: "Withdrawing and trying to solve it on my own"),
                    PersonalityOption(id: "B",letter: "B", text: "Weighing the pros and cons, and problem solving"),
                    PersonalityOption(id: "C",letter: "C", text: "Reaching out to others for support or advice"),
                    PersonalityOption(id: "D",letter: "D", text: "Getting things off my chest"),
                ]
            ),
            PersonalityQuestion(
                question: "Overall, I’m looking for someone that will...",
                options: [
                    PersonalityOption(id: "A",letter: "A", text: "Relax and have thoughtful conversations with me"),
                    PersonalityOption(id: "B",letter: "B", text: "Bring me out of my shell and make me feel comfortable"),
                    PersonalityOption(id: "C",letter: "C", text: "Ground me, and be a good listener when I need it"),
                    PersonalityOption(id: "D",letter: "D", text: "Match my adventurous spirit and keep up with my high energy"),
                ]
            ),
        ]
}

