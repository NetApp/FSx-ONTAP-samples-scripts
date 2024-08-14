export const copyToClipboard = async (textToCopy: string) => {
    await window.navigator.clipboard.writeText(textToCopy);
}