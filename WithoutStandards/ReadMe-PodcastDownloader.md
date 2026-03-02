# Podcast Downloader
A simple application to download multiple podcasts from a CSV file. For each podcast assume we want a weaks worth of them. 

## Example:
I've been using this to download podcasts:
```
npx podcast-dl --include-meta --include-episode-meta --include-episode-transcripts --include-episode-images --before 12/31/2016 --after 01/01/2016 --file hello.rss.xml
```

the args `--before 12/31/2016 --after 01/01/2016` indicate the timespan to download them. You can re-write these to be a week's worth from today's date. 

## Podcast file
Podcasts are distributed via xml files hosted on a webserver somewhere. With a given feed URL you should download it via:

```
curl -L -o hello.rss.xml https://example.com/hello.feed
```

Note: Curl should have the params to follow redirects like -L so empty files aren't produced.

## CSV format
The bash script will be given a CSV with a header row. The header can be assumed to always be in the same order. 

```txt
Folder,URL,Feed URL
audiopodcast-hello,https://example.com/hello,https://example.com/hello.feed
videopodcast-hello,https://example.com/hello,https://example.com/hello-video.feed
```