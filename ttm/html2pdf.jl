function html_to_pdf(html_file, pdf_file)
    run(`node -e "
        const puppeteer = require('puppeteer');
        (async () => {
            const browser = await puppeteer.launch();
            const page = await browser.newPage();
            await page.goto('file://$html_file', {waitUntil: 'networkidle0'});
            await page.pdf({path: '$pdf_file', format: 'A4'});
            await browser.close();
        })();
    "`)
end
