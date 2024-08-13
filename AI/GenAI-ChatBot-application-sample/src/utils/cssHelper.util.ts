declare namespace classNames {
  type Value = string | number | boolean | undefined | null;
  type Mapping = Record<string, any>;
  interface ArgumentArray extends Array<Argument> { }
  interface ReadonlyArgumentArray extends ReadonlyArray<Argument> { }
  type Argument = Value | Mapping | ArgumentArray | ReadonlyArgumentArray;
}

export const _Classes = (...classes: classNames.ArgumentArray): string => {
  const classList: string[] = [];
  classes.forEach(_class => {
    if (typeof _class === 'string') {
      classList.push(_class);
    } else if (_class && typeof _class === 'object') {
      Object.entries(_class).forEach(entry => {
        if (entry[1] === true) {
          classList.push(entry[0]);
        }
      })
    }
  })


  return classList.join(' ');
}

export const getCssVariableValue = (variableName: string) =>
  getComputedStyle(document.body).getPropertyValue(variableName);

export const convertPxStringToNumber = (pxWidth: string): number =>
  +pxWidth.slice(0, -2);

export const calculateBreakpointWidth = (
  cssVariableName: string,
  isIframe: boolean
) => {
  const numeralScreenWidth = convertPxStringToNumber(
    getCssVariableValue(cssVariableName)
  );
  const smallResolutionWidth = convertPxStringToNumber(
    getCssVariableValue('--Small_Resolution_Breakpoint')
  );
  const leftPanelWidth = !isIframe
    ? 0
    : numeralScreenWidth <= smallResolutionWidth
      ? 48
      : 72;
  return `${numeralScreenWidth - leftPanelWidth}px`;
};