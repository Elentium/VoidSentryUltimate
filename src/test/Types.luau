export type TestResult = {
    Name: string,
    Valid: boolean,
}

export type Section = {
    SectionName: string,
    Nodes: { TestResult },
}

export type Results = { Section }

return nil
