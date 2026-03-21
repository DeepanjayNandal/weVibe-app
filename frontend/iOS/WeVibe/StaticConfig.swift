import Foundation
import SwiftUI

enum StaticConfig {
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
    
    static let personalityMeta: [Int: PersonalityMeta] = [
        0: PersonalityMeta(
            type: "Serene Soul",
            emoji: "🌿",
            color: Color(hex: "#3DFF9A"),
            description: "You exude calm and grounded energy. Others might describe you as quiet and reserved because you take solace in hobbies like reading, baking, drawing, and solo sports. Due to your introverted nature, you can feel drained by socializing and overwhelmed by loud or high energy individuals. You seek someone with whom you can have deep intellectual conversations, relax, and unwind — a counterpart who will match your energy."
        ),
        1: PersonalityMeta(
            type: "Empathetic Companion",
            emoji: "💚",
            color: Color(hex: "#00E5A0"),
            description: "You are quiet and calm in your alone time, but equally enjoy the company of others — particularly those who are more outgoing than you. You are an exceptional listener with a great deal of empathy, making you the perfect confidant. Once people get to know you, you become incredibly talkative and engaging. You seek someone outgoing, adventurous, and willing to bring some spontaneity into your life."
        ),
        2: PersonalityMeta(
            type: "Radiant Dreamer",
            emoji: "✨",
            color: Color(hex: "#B2F542"),
            description: "You are very optimistic and friendly, even to strangers. You are the kind of person to start conversations on any random topic, full of creative ideas and in need of an audience to share them with. You want to feel like the center of attention, love going on adventures, but need a partner to help figure out the logistics. You seek someone to ground you at times."
        ),
        3: PersonalityMeta(
            type: "Fierce Spark",
            emoji: "🔥",
            color: Color(hex: "#FFE066"),
            description: "You are thrill-seeking with a fiery, high-energy personality. You need to socialize and be around others in order to feel recharged — you light up a room with your charisma. You need a partner in crime, someone who can handle your honesty and won't find you boring. You seek someone who can match your energy and keep up with your pace."
        ),
    ]
}
