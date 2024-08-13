import React, { FunctionComponent, useMemo } from "react";
import './prompt.scss';
import UserIcon from '@/app/svgs/chatbot/user.svg';
import BotIcon from "@/app/svgs/chatbot/bot.svg";
import parse from 'html-react-parser';
import { formatDate } from "@/utils/formatterUtils";
import { MessageType } from "@/lib/api/api.types";
import StatusIcon from "../../iconComponents/statusIcon";
import { DsTypography } from "../../dsComponents/dsTypography/dsTypography";
import { DsFlashingDotsLoader } from "../../dsComponents/dsFlashingDotsLoader/dsFlashingDotsLoader";
import { Popover } from "../../dsComponents/Popover";

export type UserType = 'USER' | 'BOT';

export interface PromptItem {
    chatId: string,
    user: UserType,
    question: string,
    message?: string,
    date?: number,
    isWriting: boolean,
    fileNames?: string[],
    isTemp: boolean,
    type: MessageType
}

interface PromptProps {
    id: string,
    className?: string,
    prompt: PromptItem
}

const Prompt: FunctionComponent<PromptProps> = ({ className, prompt, id }) => {
    const { user, isWriting, message, date, fileNames, type } = prompt;

    const baloon = useMemo(() => {
        let htmlString = message!.replace(/<answer>|<\/answer>|<response>|<\/response>|<reply>|<\/reply>/gi, '')
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').trim();
        htmlString = htmlString.replace(/^\\n/, ''); //do not add a break line at the beginning of a text
        htmlString = htmlString.replaceAll('\n', '<br/>');

        const Citations = () => {
            const maxFileLengthArray = fileNames?.slice(0, 5);

            return (
                <div className="citationComponent">
                    {maxFileLengthArray?.map((fileName, index) => {
                        const dirs = fileName.split('/');
                        const name = dirs.slice(dirs.length - 1, dirs.length);
                        const path = dirs.slice(dirs.length - 4 < 0 ? 0 : dirs.length - 4, dirs.length - 1).join('/');


                        return (
                            <div className="citationItem" key={index}>
                                <div className="citationRow">
                                    <DsTypography variant="Semibold_13" className="citationPopTitle">File name:&nbsp;</DsTypography>
                                    <DsTypography variant="Regular_13" className="citationValue">{name}</DsTypography>
                                </div>
                                <div className="citationRow">
                                    <DsTypography variant="Semibold_13" className="citationPopTitle">Path:&nbsp;</DsTypography>
                                    <DsTypography variant="Regular_13" className="citationValue">{path || '/'}</DsTypography>
                                </div>
                            </div>
                        )
                    })}
                </div>
            )
        }

        return (
            <div className="baloonContainer">
                <div className={`baloon ${user === 'USER' ? 'user' : 'bot'}`}>
                    <div className={`messageContainer ${user === 'BOT' && type === 'ERROR' ? 'withError' : ''}`}>
                        {user === 'BOT' && type === 'ERROR' && <StatusIcon status="FAILED" className="errorIcon" width={20}/>}
                        <DsTypography variant="Regular_14" className={`promptMessage  ${isWriting && !!htmlString ? 'textWriting' : ''}`} >{parse(htmlString)}</DsTypography>
                    </div>
                    {isWriting && <DsFlashingDotsLoader className={`${isWriting && !!htmlString ? 'flashingDots' : ''}`} />}
                </div>
                {(user === 'BOT' && !isWriting) && <div className="citation" id={id}>
                    {!!date && <DsTypography variant="Regular_12" className="promptDateTime">{formatDate(date)}</DsTypography>}
                    {user === 'BOT' && fileNames && fileNames.length > 0 && <Popover
                        popoverClass='citationPop'
                        container={<DsTypography variant="Regular_12" className="citationTitle">{`View citation (${Math.min(fileNames.length, 5)})`}</DsTypography>}
                        placement='auto'
                        trigger={"hover"}>
                        <Citations />
                    </Popover>}
                </div>}
            </div>
        )
    }, [isWriting, message, user, date, fileNames, type, id]);

    return (
        <div className={`promptItem fadeIn ${className || ''}`}>
            {user === 'USER' ? <UserIcon className="avatar" height={39.78}/> : <BotIcon className="avatar" height={39.78}/>}
            {baloon}
            <div id={id}>{ }</div>
        </div>
    )
}

export default Prompt;