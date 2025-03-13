import { ReactElement, RefObject, useMemo, useState } from "react";
import './prompt.scss';
import UserIcon from '@/app/[locale]/svgs/chatbot/user.svg';
import BotIcon from "@/app/[locale]/svgs/chatbot/bot.svg";
import LocationIcon from "@/app/[locale]/svgs/location.svg";
import ArrowDown from "@/app/[locale]/svgs/arrowDown.svg";
import parse from 'html-react-parser';
import { formatDate } from "@/utils/formatterUtils";
import { FileData, MessageType } from "@/lib/api/api.types";
import StatusIcon from "../../iconComponents/statusIcon";
import { DsTypography } from "../../dsComponents/dsTypography/dsTypography";
import { DsFlashingDotsLoader } from "../../dsComponents/dsFlashingDotsLoader/dsFlashingDotsLoader";
import { useOutsideClick } from "@/app/[locale]/hooks/useOutsideClick";
import { _Classes } from "@/utils/cssHelper.util";
import { DsPopover } from "../../dsComponents/dsPopover/dsPopover";
import CopyToClipboard from "../../copyToClipboard/copyToClipboard";
import { DsCellProps } from "../../dsComponents/dsTable/dsCell/dsCell";
import { DsColumn, DsRow, DsTable } from "../../dsComponents/dsTable/dsTable";
import { useTranslation } from "react-i18next";


export type UserType = 'USER' | 'BOT';

export interface PromptItem {
    chatId: string,
    user: UserType,
    question: string,
    message?: string,
    date?: number,
    isWriting: boolean,
    filesData?: FileData[],
    isTemp: boolean,
    type: MessageType
}

interface PromptProps {
    id: string,
    className?: string,
    prompt: PromptItem,
    chatAreaRef: RefObject<HTMLDivElement | null>
}

const Prompt = ({ className, prompt, id, chatAreaRef }: PromptProps) => {
    const { t } = useTranslation();
    const { user, isWriting, message, date, filesData, type } = prompt;

    const [isExpandCitations, setIsExpandCitations] = useState<boolean>(false)
    const [expandCitationsId, setExpandCitationsId] = useState<number>()

    const clickOutsideRef = useOutsideClick(() => {
        setExpandCitationsId(undefined)
    });

    const baloon = useMemo(() => {
        let htmlString = message!.replace(/<answer>|<\/answer>|<response>|<\/response>|<reply>|<\/reply>/gi, '')
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').trim();
        htmlString = htmlString.replace(/^\\n/, ''); //do not add a break line at the beginning of a text
        htmlString = htmlString.replaceAll('\n', '<br/>');

        const Citations = () => {
            const [popoverHight, setpopoverHight] = useState<number>(0);

            const maxCitation = 5;
            const maxFileLengthArray = filesData?.slice(0, maxCitation);

            return (
                <>
                    {maxFileLengthArray?.map((fileData, index) => {
                        const dirs = fileData.fileName.split('/');
                        const name = dirs.slice(dirs.length - 1, dirs.length);
                        const path = dirs.slice(dirs.length - 4 < 0 ? 0 : dirs.length - 4, dirs.length - 1).join('/');

                        const handleCitationClick = (citationsId: number) => {
                            if (expandCitationsId === undefined || expandCitationsId !== citationsId) {
                                setExpandCitationsId(citationsId)
                            } else if (expandCitationsId === citationsId) {
                                setExpandCitationsId(undefined)
                            }
                        }

                        const getBaloonHight = (index: number) => {
                            setTimeout(() => {
                                const popoverLayout = document.getElementById(`popoverLayout_${index}`);
                                if (popoverLayout) {
                                    setpopoverHight(popoverLayout.getBoundingClientRect().height);
                                }
                            }, 200);
                        }

                        return (
                            <DsPopover
                                trigger="manual"
                                monitorPosition="off"
                                key={index}
                                status={expandCitationsId === index ? 'open' : 'closed'}
                                maxBalloonWidth="480px"
                                offset={{ top: (popoverHight + 52) * -1, left: 40 }}
                                className={_Classes("citationRowContainer")}
                                onStatusChange={status => status === 'open' ? getBaloonHight(index) : undefined}
                                title={<div className="popoverLayout citationPopover" id={`popoverLayout_${index}`}>
                                    <div className="content">
                                        <div className="titleLayout">
                                            <DsTypography variant="Semibold_13" className="nameTitle">{name}</DsTypography>
                                            <CopyToClipboard
                                                tooltipTitle="Response"
                                                value={`${name}\n\n${fileData.text}\n\nPath: ${path}`}
                                                className="citationCopyIcon" monitorPosition="off"
                                                offset={{ left: -30 }} />
                                        </div>
                                        <DsTypography className="citationText" variant="Regular_13" >{fileData.text}</DsTypography>
                                    </div>
                                    <div className="citationPathLayout">
                                        <div>
                                            <LocationIcon className="locationIcon" />
                                        </div>
                                        <div className="citationPathsText">
                                            <DsTypography variant="Regular_13" >{path}</DsTypography>
                                        </div>
                                    </div>
                                </div>}>
                                <div className={_Classes("citationRowLayout", { open: expandCitationsId === index })} onClick={() => handleCitationClick(index)}>
                                    <DsTypography variant="Regular_13" >{index + 1}</DsTypography>
                                    <DsTypography variant="Regular_13" className="citationFileName">{name}</DsTypography>
                                </div>
                            </DsPopover>
                        )
                    })
                    }
                </>
            )
        }

        const promptBuilder = (): ReactElement => {
            const TABLE_TAG_START = '&lt;table&gt;';
            const TABLE_TAG_END = '&lt;/table&gt;';

            const generateTable = (tableString: string): ReactElement => {
                const regex = /{[^}]*}/g;
                const matchRows = tableString.replaceAll('<br/>', '').match(regex);

                const columns: DsColumn[] = [];
                const data: DsRow[] = [];

                if (matchRows && matchRows?.length > 0) {
                    try {
                        const columnKeys = Object.keys(JSON.parse(matchRows[0]));
                        columnKeys.forEach((key) => {
                            columns.push({ id: key, value: key });
                        });

                        matchRows.forEach((row, index) => {
                            const cells: { [columnId: string]: DsCellProps } = {};
                            columnKeys.forEach((key) => {
                                cells[key] = {
                                    value: JSON.parse(row)[key]
                                };
                            });

                            data.push(
                                {
                                    id: index.toString(),
                                    cells
                                }
                            );
                        });

                        const tableMaxHeight = chatAreaRef.current ? chatAreaRef.current.getBoundingClientRect().height * .85 : undefined;

                        return (
                            <DsTable columns={columns}
                                data={data}
                                isSearchable={false}
                                variant="light"
                                isHorizontalScroll={true}
                                maxHeight={tableMaxHeight}
                            />
                        )
                    } catch (error) {
                        return <>{tableString}</>
                    }
                }

                return <></>;

            }

            const generatePromptString = (): ReactElement => {
                const indexTableTagStart = htmlString.toLowerCase().indexOf(TABLE_TAG_START);
                const indexTableTagEnd = htmlString.toLowerCase().indexOf(TABLE_TAG_END);

                let promptString = <></>;

                if (indexTableTagStart === -1) {
                    promptString = <>{parse(htmlString)}</>;
                } if (indexTableTagStart > -1) {
                    const initString = `${htmlString.slice(0, indexTableTagStart)}${indexTableTagStart > 0 ? '<br/>' : ''}`;
                    promptString = <>
                        {parse(initString)}
                        {generateTable(htmlString.slice(indexTableTagStart, indexTableTagEnd > -1 ? indexTableTagEnd + TABLE_TAG_END.length : htmlString.length))}
                    </>
                }

                if (indexTableTagEnd > -1) {
                    promptString = <>
                        {promptString}
                        {parse(htmlString.slice(indexTableTagEnd + TABLE_TAG_END.length, htmlString.length))}
                    </>
                }

                return promptString;
            }

            return (
                <DsTypography variant="Regular_14" className={`promptMessage  ${isWriting && !!htmlString ? 'textWriting' : ''}`} >{generatePromptString()}</DsTypography>
            )
        }

        return (
            <div className="baloonContainer">
                <div className={`baloon ${user === 'USER' ? 'user' : 'bot'}`}>
                    <div className={_Classes('messageContainer', { withError: user === 'BOT' && type === 'ERROR' })}>
                        {user === 'BOT' && type === 'ERROR' && <StatusIcon status="FAILED" className="errorIcon" />}
                        {promptBuilder()}
                    </div>
                    {isWriting && <DsFlashingDotsLoader className={`${isWriting && !!htmlString ? 'flashingDots' : ''}`} />}
                    {(user === 'BOT' && !isWriting) && <div className="dateAndCopyLayout" id={id}>
                        {!!date && <DsTypography variant="Regular_12" className="promptDateTime">{formatDate(date)}</DsTypography>}
                        <CopyToClipboard
                            tooltipTitle="Response"
                            value={message ? message : ""}
                            monitorPosition="off"
                            offset={{ top: -80, left: 20 }}
                            className="copyPrompt">
                            <DsTypography variant="Semibold_14" className="copyLabel">{t('genAI.general.copy')}</DsTypography>
                        </CopyToClipboard>
                    </div>}
                    {(user === 'BOT' && !isWriting) && filesData && filesData.length > 0 && <div className="citationsLayout">
                        <div
                            className="sourcesLayout"
                            onClick={() => setIsExpandCitations(!isExpandCitations)}>
                            <DsTypography variant="Semibold_13" className="sourceLabel">{`${t('genAI.chatBot.citations.sources')} ${Math.min(filesData.length, 5)}`}</DsTypography>
                            <ArrowDown className={_Classes("arrowIcon", { open: isExpandCitations })} />
                        </div>
                        <div className={_Classes("citationsContainer", { open: isExpandCitations })}
                            ref={clickOutsideRef}>
                            <Citations />
                        </div>
                    </div>}
                </div>
            </div>
        )
    }, [message, user, type, isWriting, id, date, t, filesData, isExpandCitations, clickOutsideRef, expandCitationsId, chatAreaRef]);

    return (
        <div className={`promptItem fadeIn ${className || ''}`}>
            <div className="promptContent">
                {user === 'USER' ? <UserIcon className="avatar" /> : <BotIcon className="avatar" />}
                {baloon}
            </div>
            <div id={id}>{ }</div>
        </div>
    )
}

export default Prompt;
