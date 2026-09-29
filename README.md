# Privacy Scripts in Bash

## Project Report

This project began as a practical effort to improve personal privacy on Linux systems by creating a small set of Bash scripts that are easy to understand and use. The aim was not to build a large framework, but to develop focused tools that can help reduce exposure to sensitive information, tighten access to important files, and lower the amount of digital trace left behind during regular computer use.

The overall idea was to make basic privacy tasks simple enough to run from the terminal, while also leaving room to combine them later into a single graphical interface. The result was a set of tools that can sanitize logs, secure files, clean histories, and improve local network privacy without requiring a major software stack.

The first step was to identify the main privacy issues that matter in day-to-day Linux use. These include the accidental sharing of personal details in logs or text documents, files with permissions that are too open, shell history that records command activity, caches and temporary files that remain after use, and the risk of device tracking through hardware identifiers such as the MAC address.

The project was structured around seven distinct tasks, each addressing a specific privacy concern while staying simple and independent. This made it easier to test each feature individually and then bring them together in a single menu-driven program later.

1. Sanitizing logs and text files

The first script focused on removing personally identifiable information from text-based files. This was done by searching for common patterns such as email addresses, IP addresses, and phone numbers, then replacing them with a neutral placeholder. This helps when log files or reports need to be shared, archived, or moved outside a secure environment.

The approach used regular expressions in Bash so that the process would remain lightweight and effective. In practice, this means a user can pass a file to the script and receive a cleaned version without having to manually edit each entry.

2. Tightening file permissions

A second script focused on file security by checking for files with overly permissive permissions. In many Linux environments, files may be set to 777, which allows other users or processes to read, write, or execute them. That kind of openness is a risk when the content is sensitive or personal.

The script scans target directories and resets those files to a more secure permission level, such as 600, which restricts access to the owner. This is especially valuable for private documents, configuration files, and data that should not be readable by anyone else.

3. Protecting private-key directories

The project also included a step for securing directories such as .ssh and .gnupg. These folders often contain credentials, private keys, and other sensitive material. If they are too open, they can become an easy point of access for unauthorized users.

The script adjusts directory permissions to 700 and file permissions to 600 to ensure that only the active user can access those files. This is a simple and effective safeguard for SSH and GPG operations.

4. Clearing system traces

Another part of the toolkit was focused on clearing traces left behind by regular system use. This includes removing shell history, deleting temporary files, and wiping caches from common applications. These artifacts may not appear important at first, but they can reveal command activity, browsing information, or other digital traces.

The cleaning routine was designed to be straightforward and practical, focusing on the files users commonly leave behind while working in a Linux environment. This reduces the amount of data that could be recovered later and improves the overall level of privacy.

5. Rotating MAC addresses

The next area of work involved local network privacy. A script was developed to change the MAC address of a network adapter so that device tracking becomes more difficult on a local network. This is not a perfect security measure, but it can help reduce a device’s visibility in certain situations.

The process involved taking the interface down, setting a new locally administered MAC address, and bringing it back up. This is a useful privacy measure when the goal is to reduce tracking by local network observers, though it should always be used carefully and with awareness of the system configuration.

6. Toggling VPN connections

The project also included a script to connect or disconnect a VPN using NetworkManager. This allows the user to switch the connection state quickly without manually navigating through multiple settings menus. With a VPN connection in place, traffic can be routed through a secure tunnel and protected from some forms of local interception or exposure.

This part of the project was included because VPN access is one of the easiest and most effective privacy controls available to a regular user on a desktop system.

7. Combining the tools into one interface

Once the seven basic scripts were working, the next logical step was to combine them into a single Bash-based graphical program. The aim was to make the whole toolkit easier to use by presenting the actions in a simple menu. Instead of running multiple commands in a terminal, the user could choose options from a desktop dialog and have the program execute the relevant task.

The combined version was targeted at a Lenovo ThinkPad running Fedora with KDE Plasma. The interface was kept simple so it would work well in a standard desktop environment and remain easy to maintain. This helped ensure the program could be used by someone with basic Linux knowledge without needing a large learning curve.

The design principle behind this step was simple: each function should remain independent and clear, but also easy to call from a single interface. That way, the individual scripts remain useful on their own, while the combined tool brings them together for convenience and faster daily use.

### Conclusion

This project shows that Bash can be a practical tool for personal privacy and system hygiene on Linux. The scripts are lightweight, understandable, and easy to maintain, which makes them useful for everyday privacy tasks without requiring a heavy software stack.

By combining these functions into one graphical tool, the original concept becomes much easier to use in daily work. The result is a system that helps protect private information, reduce digital traces, and make privacy maintenance simpler for the average user.

The project is still open to future growth. More features can be added over time, but the underlying foundation is already solid: small scripts, clear functionality, and a straightforward approach to privacy protection on Linux systems.

- ** sudo dnf install hwinfo
