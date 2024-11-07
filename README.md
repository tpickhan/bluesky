# Bluesky.ms

🦋 → [bluesky.ms](https://bluesky.ms) = Search for folks in the Microsoft community on Bluesky!

This repository hosts the source code for [bluesky.ms](https://bluesky.ms), a crowd sourced database of Bluesky profiles.

![image](/website/static/OpenGraphImage.png)

## Contributing

There are a few different ways to contribute to this project.

### Adding a new Bluesky profile

#### By submitting an issue (recommended)

This is the easiest way to add a profile and will result in the profile being added to the site in minutes. Use the [New Blueskey profile link](https://github.com/merill/bluesky/issues/new?assignees=&labels=&template=add-profile.yaml&title=New+Bluesky+profile+) issue template to submit a new profile.

#### By submitting a pull request (advanced)

This option is best to make updates to existing profiles, delete profiles and bulk add profiles.

Each profile is stored as a .json file at [/website/config](https://github.com/merill/bluesky/tree/main/website/config).

Some conventions to follow when creating a pull request using this method.

* The file name is name of the profile. e.g.

| Bluesky Profile | File Name |
| --- | --- |
| https://bsky.app/profile/merill.net | merill.net.json |
| https://bsky.app/profile/john.bsky.social | john.bsky.social.json |

* The file name should be lower case.
* Contents in the file
  * **url** - The full url to the profile. e.g. https://bsky.app/profile/merill.net
  * **name** - The name of the person. e.g. Merill Fernando
  * **type** - Optional. Specify if the profile belongs to a Microsoft employee or an MVP, otherwise leave blank. Supported values are: microsoft, mvp
  * **category** - The Microsoft product, service or group this profile is associated with. This is used to group products together on the site.
    * New categories can be added (check the dropdown on the site for the list of existing categories). Avoid adding alternate names for existing categories.
    * When adding a new category, update the [Add bluesky.ms issue template](https://github.com/merill/bluesky/blob/main/.github/ISSUE_TEMPLATE/add-profile.yaml) to include the new category.
    * If you wish to go the extra mile you can also add an icon for the category at [/static/img/](https://github.com/merill/bluesky/tree/main/website/static/img). This is optional, a default icon will be used if a custom one is not provided.

### Reporting Issues

Open a [new bug](https://github.com/merill/bluesky/issues/new?assignees=&labels=&template=add-bug.yaml&title=%5BBug%5D) to report issues.
