import styles from './chat.module.scss';
import UpperBar from '../components/upperBar/upperBar';
import Chatbot from '../components/chatbot/chatbot';

const Chat = () => {
    return (
        <div className={styles.chat}>
            <UpperBar />
            <Chatbot />
        </div>
    )
}

export default Chat;