# FSx for NetApp ONTAP (FSxN) Developer Guide: Contributing to the Code Sample Repository

Welcome! This guide is designed to help developers contribute code samples and automation scripts to the official FSxN code sample repository hosted by NetApp. By following these guidelines, you'll ensure your contributions are well-structured, informative, and easy for others to understand and use.

## Getting Started
This repository utilizes a standard Git branching model for contributions. Here's a quick overview of the workflow:

1. **Fork the Repository:** Before making changes, you'll need to fork this repository to your own GitHub account. This creates a copy of the code that you can modify without affecting the original project.

2. **Create a Feature Branch:** Make your changes on a new branch specifically for your contribution. Use a descriptive branch name that reflects the feature or functionality you're adding (e.g., "feature-volume-snapshot-automation"). Avoid using personal names or unclear titles.

3. **Commit Your Changes:** As you work, commit your changes regularly with clear and concise commit messages. These messages should describe what each commit modifies.

4. **Push Changes to Your Fork:** Once you're happy with your changes, push your feature branch to your forked repository.

5. **Create a Pull Request (PR):** Submit a pull request to merge your feature branch into the main branch of the upstream repository. This initiates a code review process.

## Code Contribution Guidelines
We welcome contributions that showcase the capabilities of FSxN through code samples and automation scripts. Here are some additional guidelines to keep in mind:

- **Code Quality:** We strive for high-quality code. Ensure your code is well-formatted, follows best practices, and includes comments to explain its functionality.

- **Testing:** Whenever possible, include unit tests or integration tests to validate the functionality of your code sample.

- **Legal Approval:** Before pushing code to the repository, please reach out to the repository owner for approval. This ensures proper legal considerations are addressed.

> [!CAUTION]
> **Never push code directly to the main branch! All contributions must go through a pull request process.**


## Documentation Standards

Clear and informative documentation is crucial for users to understand and utilize your code samples effectively.  Here's the recommended structure for your code sample's `README.md` file:

### Required Sections:

- **Introduction:**
    - Briefly explain the purpose of the code sample
    - Describe the functionality it demonstrates
    - Mention the specific FSxN features involved

- **Prerequisites:**
    - List any software, resources, or configurations needed to run the code sample.
    - Include instructions for setting up these prerequisites (e.g., AWS account, specific FSxN version).

- **Usage:**
    - Provide a step-by-step guide on how to use the code sample
    - Start with cloning the repository and setting up the environment
    - Include clear instructions for executing the code
    - Offer at least one concrete example demonstrating its usage

- **Author Information:**
The content of this section should be identical in all sub-directories and can be copied from another README file in the repository.

- **License:**
The content of this section should be identical in all sub-directories and can be copied from another README file in the repository.

### Additional Tips:

- Use clear and concise language
- Consider including screenshots or diagrams to enhance understanding
- Provide links to relevant documentation for further reference

## Repository Structure

The repository is organized with folders representing different functionalities or "tracks" (e.g., Terraform, Monitoring, Solutions). Each code sample should reside in its own dedicated subfolder within the appropriate track. This subfolder should contain all relevant code/configuration files and the `README.md` file.

### Naming Conventions:

- Code sample subfolder names should be lowercase with dashes (e.g., "create-volume")
- Track subfolders start with an uppercase letter followed by lowercase (e.g., "Terraform")
- File names within the subfolder can be named freely, except for the mandatory `README.md`

> [!NOTE]
> The repository owner can guide you on the appropriate location for your specific contribution.

## General Best Practices
In addition to the above, here are some recommended practices for contributing to public repositories on GitHub:

- **Be respectful:** Maintain a professional and courteous tone in your interactions with other contributors
- **Stay up-to-date:** Review the latest changes and discussions in the repository before submitting your contribution
- **Respond to feedback:** Actively participate in the review process and address any feedback or questions raised on your pull request

© 2024 NetApp, Inc. All Rights Reserved.




