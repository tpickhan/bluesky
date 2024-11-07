/**
 * @name build.js
 * @description Creates source code from .json config files.
 */

const fs = require('fs');
const path = require('path');
const { parse } = require('csv-parse');
const os = require('os');

function createJsonFile(commands) {
    const cmds = JSON.stringify(commands);

    let jsonContent = 'export const commands = ' + cmds;
    console.log('Creating commands.table.js');
    fs.writeFileSync('./src/tableHome/commands.table.js', jsonContent);
    console.log('Commands file created successfully.')
}

async function run() {

    console.log('Reading aka .json files');

    const jsonsInDir = fs.readdirSync('./config').filter(file => path.extname(file) === '.json');
    const svgsInDir = fs.readdirSync('./static/img').filter(file => path.extname(file) === '.svg');
    const svgFiles = svgsInDir.map(filename => filename.replace(/\.[^/.]+$/, "")); //Remove all file extensions to compare with category

    let akaLinks = [];

    jsonsInDir.forEach(file => {
        const fileData = fs.readFileSync(path.join('./config', file));
        const json = JSON.parse(fileData.toString());

        //Calculate the icon to show
        json.categoryShortName = 'general' //Default icon
        //Domain based icons override others
        if (json.category && svgFiles.includes(json.category)) {
            json.categoryShortName = json.category
        }

        if(!(json.type === 'mvp' || json.type === 'microsoft')) {
            json.type = 'general';
        }

        akaLinks.push(json);
    });

    akaLinks.sort((a, b) => a.title.localeCompare(b.title));


    createJsonFile(akaLinks);
}

run();
