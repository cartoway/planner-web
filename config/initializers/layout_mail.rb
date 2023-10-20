Rails.application.config.automation = {
    parameters: {
      accompanying_team: {
        fr: {
          contact_params: '?utm_source=fr-automation-1&utm_medium=email&utm_campaign=automation-fr-1&utm_content=link-support',
          help_params: '?utm_source=fr-automation-1&utm_medium=email&utm_campaign=automation-fr-1&utm_content=link-index-doc',
          panel_first: { link: '?utm_source=fr-automation-1&utm_medium=email&utm_campaign=automation-fr-1&utm_content=link-before-start' },
          panel_second: { link: '?utm_source=fr-automation-1&utm_medium=email&utm_campaign=automation-fr-1&utm_content=link-start' },
          panel_third: { link: '?utm_source=fr-automation-1&utm_medium=email&utm_campaign=automation-fr-1&utm_content=link-global-settings' }
        },
        en: {
          contact_params: '?utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-1&utm_content=link-support-1',
          help_params: '?utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-1&utm_content=link-doc-index-1',
          panel_first: { link: '?utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-1&utm_content=link-before-start' },
          panel_second: { link: '?utm_source=en-automation-1&utm_medium=email&utm_campaign=automation&utm_content=link-start' },
          panel_third: { link: '?utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-1&utm_content=link-global-settings' }
        },
        image_links: {
          panel_first: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMWVtIiB2aWV3Qm94PSIwIDAgNDQ4IDUxMiI+PCEtLSEgRm9udCBBd2Vzb21lIEZyZWUgNi40LjIgYnkgQGZvbnRhd2Vzb21lIC0gaHR0cHM6Ly9mb250YXdlc29tZS5jb20gTGljZW5zZSAtIGh0dHBzOi8vZm9udGF3ZXNvbWUuY29tL2xpY2Vuc2UgKENvbW1lcmNpYWwgTGljZW5zZSkgQ29weXJpZ2h0IDIwMjMgRm9udGljb25zLCBJbmMuIC0tPjxwYXRoIGQ9Ik0zNDkuNCA0NC42YzUuOS0xMy43IDEuNS0yOS43LTEwLjYtMzguNXMtMjguNi04LTM5LjkgMS44bC0yNTYgMjI0Yy0xMCA4LjgtMTMuNiAyMi45LTguOSAzNS4zUzUwLjcgMjg4IDY0IDI4OEgxNzUuNUw5OC42IDQ2Ny40Yy01LjkgMTMuNy0xLjUgMjkuNyAxMC42IDM4LjVzMjguNiA4IDM5LjktMS44bDI1Ni0yMjRjMTAtOC44IDEzLjYtMjIuOSA4LjktMzUuM3MtMTYuNi0yMC43LTMwLTIwLjdIMjcyLjVMMzQ5LjQgNDQuNnoiLz48L3N2Zz4K',
          panel_second: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMWVtIiB2aWV3Qm94PSIwIDAgNTEyIDUxMiI+PCEtLSEgRm9udCBBd2Vzb21lIEZyZWUgNi40LjIgYnkgQGZvbnRhd2Vzb21lIC0gaHR0cHM6Ly9mb250YXdlc29tZS5jb20gTGljZW5zZSAtIGh0dHBzOi8vZm9udGF3ZXNvbWUuY29tL2xpY2Vuc2UgKENvbW1lcmNpYWwgTGljZW5zZSkgQ29weXJpZ2h0IDIwMjMgRm9udGljb25zLCBJbmMuIC0tPjxwYXRoIGQ9Ik0zMzYgMzUyYzk3LjIgMCAxNzYtNzguOCAxNzYtMTc2UzQzMy4yIDAgMzM2IDBTMTYwIDc4LjggMTYwIDE3NmMwIDE4LjcgMi45IDM2LjggOC4zIDUzLjdMNyAzOTFjLTQuNSA0LjUtNyAxMC42LTcgMTd2ODBjMCAxMy4zIDEwLjcgMjQgMjQgMjRoODBjMTMuMyAwIDI0LTEwLjcgMjQtMjRWNDQ4aDQwYzEzLjMgMCAyNC0xMC43IDI0LTI0VjM4NGg0MGM2LjQgMCAxMi41LTIuNSAxNy03bDMzLjMtMzMuM2MxNi45IDUuNCAzNSA4LjMgNTMuNyA4LjN6TTM3NiA5NmE0MCA0MCAwIDEgMSAwIDgwIDQwIDQwIDAgMSAxIDAtODB6Ii8+PC9zdmc+Cg==',
          panel_third: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMWVtIiB2aWV3Qm94PSIwIDAgNDQ4IDUxMiI+PCEtLSEgRm9udCBBd2Vzb21lIEZyZWUgNi40LjIgYnkgQGZvbnRhd2Vzb21lIC0gaHR0cHM6Ly9mb250YXdlc29tZS5jb20gTGljZW5zZSAtIGh0dHBzOi8vZm9udGF3ZXNvbWUuY29tL2xpY2Vuc2UgKENvbW1lcmNpYWwgTGljZW5zZSkgQ29weXJpZ2h0IDIwMjMgRm9udGljb25zLCBJbmMuIC0tPjxwYXRoIGQ9Ik0yMjQgMjU2QTEyOCAxMjggMCAxIDAgMjI0IDBhMTI4IDEyOCAwIDEgMCAwIDI1NnptLTQ1LjcgNDhDNzkuOCAzMDQgMCAzODMuOCAwIDQ4Mi4zQzAgNDk4LjcgMTMuMyA1MTIgMjkuNyA1MTJINDE4LjNjMTYuNCAwIDI5LjctMTMuMyAyOS43LTI5LjdDNDQ4IDM4My44IDM2OC4yIDMwNCAyNjkuNyAzMDRIMTc4LjN6Ii8+PC9zdmc+Cg=='
        }
      },
      features: {
        fr: {
          contact_params: '?utm_source=fr-automation-2&utm_medium=email&utm_campaign=automation-fr-2&utm_content=link-support-2',
          help_params: '?utm_source=fr-automation-2&utm_medium=email&utm_campaign=automation-fr-2&utm_content=link-index-doc-2',
          panel_first: {
            link: '?utm_source=fr-automation-2&utm_medium=email&utm_campaign=automation-fr-2&utm_content=link-vehicles-config',
            youtube_links: {
              first: 'https://www.youtube.com/watch?v=9nrxDBXNabE&utm_source=fr-automation-2&utm_medium=email&utm_campaign=automation-fr-2&utm_content=link-video-vehicles-config'
            }
          },
          panel_second: {
            link: '?utm_source=fr-automation-2&utm_medium=email&utm_campaign=automation-fr-2&utm_content=link-destinations',
            youtube_links: {
              first: 'https://www.youtube.com/watch?v=PJ4cOBzinaM&utm_source=fr-automation-2&utm_medium=email&utm_campaign=automation-fr-2&utm_content=link-video-destinations',
              second: 'https://www.youtube.com/watch?v=vhmPLcyRMcA&utm_source=fr-automation-2&utm_medium=email&utm_campaign=automation-fr-2&utm_content=link-video-tags'
            }
          },
          panel_third: {
            link: '?utm_source=fr-automation-2&utm_medium=email&utm_campaign=automation-fr-2&utm_content=link-zoning',
            youtube_links: {
              first: 'https://www.youtube.com/watch?v=h9qhEEZKzBc&utm_source=fr-automation-2&utm_medium=email&utm_campaign=automation-fr-2&utm_content=link-video-create-zoning',
              second: 'https://www.youtube.com/watch?v=ynFcGnznJcI&utm_source=fr-automation-2&utm_medium=email&utm_campaign=automation-fr-2&utm_content=link-video-change-zoning'
            }
          }
        },
        en: {
          contact_params: '?utm_source=en-automation-2&utm_medium=email&utm_campaign=automation-en-2&utm_content=link-support-2',
          help_params: '?utm_source=en-automation-2&utm_medium=email&utm_campaign=automation-en-2&utm_content=link-doc-index-2',

          panel_first: {
            link: '?utm_source=automation-en-2&utm_medium=email&utm_campaign=automation&utm_content=link-vehicle-config',
            youtube_links: {
              first: 'https://www.youtube.com/watch?v=9nrxDBXNabE&utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-2&utm_content=link-video-vehicle-config',
            }
          },
          panel_second: {
            link: '?utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-2&utm_content=link-destinations',
            youtube_links: {
              first: 'https://www.youtube.com/watch?v=PJ4cOBzinaM&utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-2&utm_content=link-video-destinations',
              second: 'https://www.youtube.com/watch?v=vhmPLcyRMcA&utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-2&utm_content=link-video-tags'
            }
          },
          panel_third: {
            link: '?utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-2&utm_content=link-zoning',
            youtube_links: {
              first: 'https://www.youtube.com/watch?v=h9qhEEZKzBc&utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-2&utm_content=link-video-create-zoning',
              second: 'https://www.youtube.com/watch?v=ynFcGnznJcI&utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-2&utm_content=link-video-change-zone'
            }
          }
        },
        image_links: {
          panel_first: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMWVtIiB2aWV3Qm94PSIwIDAgNjQwIDUxMiI+PCEtLSEgRm9udCBBd2Vzb21lIEZyZWUgNi40LjIgYnkgQGZvbnRhd2Vzb21lIC0gaHR0cHM6Ly9mb250YXdlc29tZS5jb20gTGljZW5zZSAtIGh0dHBzOi8vZm9udGF3ZXNvbWUuY29tL2xpY2Vuc2UgKENvbW1lcmNpYWwgTGljZW5zZSkgQ29weXJpZ2h0IDIwMjMgRm9udGljb25zLCBJbmMuIC0tPjxwYXRoIGQ9Ik00OCAwQzIxLjUgMCAwIDIxLjUgMCA0OFYzNjhjMCAyNi41IDIxLjUgNDggNDggNDhINjRjMCA1MyA0MyA5NiA5NiA5NnM5Ni00MyA5Ni05NkgzODRjMCA1MyA0MyA5NiA5NiA5NnM5Ni00MyA5Ni05NmgzMmMxNy43IDAgMzItMTQuMyAzMi0zMnMtMTQuMy0zMi0zMi0zMlYyODggMjU2IDIzNy4zYzAtMTctNi43LTMzLjMtMTguNy00NS4zTDUxMiAxMTQuN2MtMTItMTItMjguMy0xOC43LTQ1LjMtMTguN0g0MTZWNDhjMC0yNi41LTIxLjUtNDgtNDgtNDhINDh6TTQxNiAxNjBoNTAuN0w1NDQgMjM3LjNWMjU2SDQxNlYxNjB6TTExMiA0MTZhNDggNDggMCAxIDEgOTYgMCA0OCA0OCAwIDEgMSAtOTYgMHptMzY4LTQ4YTQ4IDQ4IDAgMSAxIDAgOTYgNDggNDggMCAxIDEgMC05NnoiLz48L3N2Zz4K',
          panel_second: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMWVtIiB2aWV3Qm94PSIwIDAgMzg0IDUxMiI+PCEtLSEgRm9udCBBd2Vzb21lIEZyZWUgNi40LjIgYnkgQGZvbnRhd2Vzb21lIC0gaHR0cHM6Ly9mb250YXdlc29tZS5jb20gTGljZW5zZSAtIGh0dHBzOi8vZm9udGF3ZXNvbWUuY29tL2xpY2Vuc2UgKENvbW1lcmNpYWwgTGljZW5zZSkgQ29weXJpZ2h0IDIwMjMgRm9udGljb25zLCBJbmMuIC0tPjxwYXRoIGQ9Ik0yMTUuNyA0OTkuMkMyNjcgNDM1IDM4NCAyNzkuNCAzODQgMTkyQzM4NCA4NiAyOTggMCAxOTIgMFMwIDg2IDAgMTkyYzAgODcuNCAxMTcgMjQzIDE2OC4zIDMwNy4yYzEyLjMgMTUuMyAzNS4xIDE1LjMgNDcuNCAwek0xOTIgMTI4YTY0IDY0IDAgMSAxIDAgMTI4IDY0IDY0IDAgMSAxIDAtMTI4eiIvPjwvc3ZnPgo=',
          panel_third: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMWVtIiB2aWV3Qm94PSIwIDAgNjQwIDUxMiI+PCEtLSEgRm9udCBBd2Vzb21lIEZyZWUgNi40LjIgYnkgQGZvbnRhd2Vzb21lIC0gaHR0cHM6Ly9mb250YXdlc29tZS5jb20gTGljZW5zZSAtIGh0dHBzOi8vZm9udGF3ZXNvbWUuY29tL2xpY2Vuc2UgKENvbW1lcmNpYWwgTGljZW5zZSkgQ29weXJpZ2h0IDIwMjMgRm9udGljb25zLCBJbmMuIC0tPjxwYXRoIGQ9Ik00OC4yIDY2LjhjLS4xLS44LS4yLTEuNy0uMi0yLjVjMC0uMSAwLS4xIDAtLjJjMC04LjggNy4yLTE2IDE2LTE2Yy45IDAgMS45IC4xIDIuOCAuMkM3NC4zIDQ5LjUgODAgNTYuMSA4MCA2NGMwIDguOC03LjIgMTYtMTYgMTZjLTcuOSAwLTE0LjUtNS43LTE1LjgtMTMuMnpNMCA2NGMwIDI2LjkgMTYuNSA0OS45IDQwIDU5LjNWMjI4LjdDMTYuNSAyMzguMSAwIDI2MS4xIDAgMjg4YzAgMzUuMyAyOC43IDY0IDY0IDY0YzI2LjkgMCA0OS45LTE2LjUgNTkuMy00MEgzMjQuN2M5LjUgMjMuNSAzMi41IDQwIDU5LjMgNDBjMzUuMyAwIDY0LTI4LjcgNjQtNjRjMC0yNi45LTE2LjUtNDkuOS00MC01OS4zVjEyMy4zYzIzLjUtOS41IDQwLTMyLjUgNDAtNTkuM2MwLTM1LjMtMjguNy02NC02NC02NGMtMjYuOSAwLTQ5LjkgMTYuNS01OS4zIDQwSDEyMy4zQzExMy45IDE2LjUgOTAuOSAwIDY0IDBDMjguNyAwIDAgMjguNyAwIDY0em0zNjggMGExNiAxNiAwIDEgMSAzMiAwIDE2IDE2IDAgMSAxIC0zMiAwek0zMjQuNyA4OGM2LjUgMTYgMTkuMyAyOC45IDM1LjMgMzUuM1YyMjguN2MtMTYgNi41LTI4LjkgMTkuMy0zNS4zIDM1LjNIMTIzLjNjLTYuNS0xNi0xOS4zLTI4LjktMzUuMy0zNS4zVjEyMy4zYzE2LTYuNSAyOC45LTE5LjMgMzUuMy0zNS4zSDMyNC43ek0zODQgMjcyYTE2IDE2IDAgMSAxIDAgMzIgMTYgMTYgMCAxIDEgMC0zMnpNODAgMjg4YzAgNy45LTUuNyAxNC41LTEzLjIgMTUuOGMtLjggLjEtMS43IC4yLTIuNSAuMmwtLjIgMGMtOC44IDAtMTYtNy4yLTE2LTE2YzAtLjkgLjEtMS45IC4yLTIuOEM0OS41IDI3Ny43IDU2LjEgMjcyIDY0IDI3MmM4LjggMCAxNiA3LjIgMTYgMTZ6bTM5MS4zLTQwaDQ1LjRjNi41IDE2IDE5LjMgMjguOSAzNS4zIDM1LjNWMzg4LjdjLTE2IDYuNS0yOC45IDE5LjMtMzUuMyAzNS4zSDMxNS4zYy02LjUtMTYtMTkuMy0yOC45LTM1LjMtMzUuM1YzNTJIMjMydjM2LjdjLTIzLjUgOS41LTQwIDMyLjUtNDAgNTkuM2MwIDM1LjMgMjguNyA2NCA2NCA2NGMyNi45IDAgNDkuOS0xNi41IDU5LjMtNDBINTE2LjdjOS41IDIzLjUgMzIuNSA0MCA1OS4zIDQwYzM1LjMgMCA2NC0yOC43IDY0LTY0YzAtMjYuOS0xNi41LTQ5LjktNDAtNTkuM1YyODMuM2MyMy41LTkuNSA0MC0zMi41IDQwLTU5LjNjMC0zNS4zLTI4LjctNjQtNjQtNjRjLTI2LjkgMC00OS45IDE2LjUtNTkuMyA0MEg0NDh2MTYuNGM5LjggOC44IDE3LjggMTkuNSAyMy4zIDMxLjZ6bTg4LjktMjYuN2ExNiAxNiAwIDEgMSAzMS41IDUuNSAxNiAxNiAwIDEgMSAtMzEuNS01LjV6TTI3MS44IDQ1MC43YTE2IDE2IDAgMSAxIC0zMS41LTUuNSAxNiAxNiAwIDEgMSAzMS41IDUuNXptMzAxLjUgMTNjLTcuNS0xLjMtMTMuMi03LjktMTMuMi0xNS44YzAtOC44IDcuMi0xNiAxNi0xNmM3LjkgMCAxNC41IDUuNyAxNS44IDEzLjJsMCAuMWMuMSAuOSAuMiAxLjggLjIgMi43YzAgOC44LTcuMiAxNi0xNiAxNmMtLjkgMC0xLjktLjEtMi44LS4yeiIvPjwvc3ZnPgo='
        }
      },
      advanced_options: {
        fr: {
          contact_params: '?utm_source=fr-automation-3&utm_medium=email&utm_campaign=automation-fr-3&utm_content=link-support-3',
          help_params: '?utm_source=fr-automation-3&utm_medium=email&utm_campaign=automation-fr-3&utm_content=link-index-doc-3',
          panel_first: {
            link: '?utm_source=fr-automation-3&utm_medium=email&utm_campaign=automation-fr-3&utm_content=link-plans',
            youtube_links: {
              first: 'https://www.youtube.com/watch?v=1xPzktNdQIg&utm_source=fr-automation-3&utm_medium=email&utm_campaign=automation-fr-3&utm_content=link-video-create-plans',
              second: 'https://www.youtube.com/watch?v=H55Pmi4sIhQ&utm_source=fr-automation-3&utm_medium=email&utm_campaign=automation-fr-3&utm_content=link-video-manage-stops',
              third: 'https://www.youtube.com/watch?v=8kABOCz0wKM&utm_source=fr-automation-3&utm_medium=email&utm_campaign=automation-fr-3&utm_content=link-video-optimization',
              fourth: 'https://www.youtube.com/watch?v=vcScpd2xCSw&utm_source=fr-automation-3&utm_medium=email&utm_campaign=automation-fr-3&utm_content=link-video-export',
              fifth: 'https://www.youtube.com/watch?v=_ggx3V9Zl6g&utm_source=fr-automation-3&utm_medium=email&utm_campaign=automation-fr-3&utm_content=link-video-gps-export'
            }
          },
          panel_second: {
            link: '?utm_source=fr-automation-3&utm_medium=email&utm_campaign=automation-fr-3&utm_content=link-webfleet',
            youtube_links: {
              first: 'https://www.youtube.com/watch?v=uqIHqSLki8U&utm_source=fr-automation-3&utm_medium=email&utm_campaign=automation-fr-3&utm_content=link-video-webfleet'
            }
          },
          panel_third: {
            link: '?utm_source=fr-automation-3&utm_medium=email&utm_campaign=automation-fr-3&utm_content=link-advanced-options'
          }
        },
        en: {
          contact_params: '?utm_source=en-automation-3&utm_medium=email&utm_campaign=automation-en-3&utm_content=link-support-3',
          help_params: '?utm_source=en-automation-3&utm_medium=email&utm_campaign=automation-en-3&utm_content=link-doc-index-3',
          panel_first: {
            link: '?utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-3&utm_content=link-plans',
            youtube_links: {
              first: 'https://www.youtube.com/watch?v=1xPzktNdQIg&utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-3&utm_content=link-video-create-plans',
              second: 'https://www.youtube.com/watch?v=H55Pmi4sIhQ&utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-3&utm_content=link-video-stops',
              third: 'https://www.youtube.com/watch?v=8kABOCz0wKM&utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-3&utm_content=link-video-optimization',
              fourth: 'https://www.youtube.com/watch?v=vcScpd2xCSw&utm_source=en-automation-1&utm_medium=email&utm_campaign=automation&utm_content=link-video-export',
              fifth: 'https://www.youtube.com/watch?v=_ggx3V9Zl6g&utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-3&utm_content=link-video-export-gps'
            }
          },
          panel_second: {
            link: '?utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-3&utm_content=link-webfleet',
            youtube_links: {
              first: 'https://www.youtube.com/watch?v=uqIHqSLki8U&utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-3&utm_content=link-video-webfleet'
            }
          },
          panel_third: {
            link: '?utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-3&utm_content=link-options'
          }
        },
        image_links: {
          panel_first: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMWVtIiB2aWV3Qm94PSIwIDAgNDQ4IDUxMiI+PCEtLSEgRm9udCBBd2Vzb21lIEZyZWUgNi40LjIgYnkgQGZvbnRhd2Vzb21lIC0gaHR0cHM6Ly9mb250YXdlc29tZS5jb20gTGljZW5zZSAtIGh0dHBzOi8vZm9udGF3ZXNvbWUuY29tL2xpY2Vuc2UgKENvbW1lcmNpYWwgTGljZW5zZSkgQ29weXJpZ2h0IDIwMjMgRm9udGljb25zLCBJbmMuIC0tPjxwYXRoIGQ9Ik0xNTIgMjRjMC0xMy4zLTEwLjctMjQtMjQtMjRzLTI0IDEwLjctMjQgMjRWNjRINjRDMjguNyA2NCAwIDkyLjcgMCAxMjh2MTYgNDhWNDQ4YzAgMzUuMyAyOC43IDY0IDY0IDY0SDM4NGMzNS4zIDAgNjQtMjguNyA2NC02NFYxOTIgMTQ0IDEyOGMwLTM1LjMtMjguNy02NC02NC02NEgzNDRWMjRjMC0xMy4zLTEwLjctMjQtMjQtMjRzLTI0IDEwLjctMjQgMjRWNjRIMTUyVjI0ek00OCAxOTJoODB2NTZINDhWMTkyem0wIDEwNGg4MHY2NEg0OFYyOTZ6bTEyOCAwaDk2djY0SDE3NlYyOTZ6bTE0NCAwaDgwdjY0SDMyMFYyOTZ6bTgwLTQ4SDMyMFYxOTJoODB2NTZ6bTAgMTYwdjQwYzAgOC44LTcuMiAxNi0xNiAxNkgzMjBWNDA4aDgwem0tMTI4IDB2NTZIMTc2VjQwOGg5NnptLTE0NCAwdjU2SDY0Yy04LjggMC0xNi03LjItMTYtMTZWNDA4aDgwek0yNzIgMjQ4SDE3NlYxOTJoOTZ2NTZ6Ii8+PC9zdmc+Cg==',
          panel_second: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMWVtIiB2aWV3Qm94PSIwIDAgNTEyIDUxMiI+PCEtLSEgRm9udCBBd2Vzb21lIEZyZWUgNi40LjIgYnkgQGZvbnRhd2Vzb21lIC0gaHR0cHM6Ly9mb250YXdlc29tZS5jb20gTGljZW5zZSAtIGh0dHBzOi8vZm9udGF3ZXNvbWUuY29tL2xpY2Vuc2UgKENvbW1lcmNpYWwgTGljZW5zZSkgQ29weXJpZ2h0IDIwMjMgRm9udGljb25zLCBJbmMuIC0tPjxwYXRoIGQ9Ik0yNjYuMyA0OC4zTDIzMi41IDczLjZjLTUuNCA0LTguNSAxMC40LTguNSAxNy4xdjkuMWMwIDYuOCA1LjUgMTIuMyAxMi4zIDEyLjNjMi40IDAgNC44LS43IDYuOC0yLjFsNDEuOC0yNy45YzItMS4zIDQuNC0yLjEgNi44LTIuMWgxYzYuMiAwIDExLjMgNS4xIDExLjMgMTEuM2MwIDMtMS4yIDUuOS0zLjMgOGwtMTkuOSAxOS45Yy01LjggNS44LTEyLjkgMTAuMi0yMC43IDEyLjhsLTI2LjUgOC44Yy01LjggMS45LTkuNiA3LjMtOS42IDEzLjRjMCAzLjctMS41IDcuMy00LjEgMTBsLTE3LjkgMTcuOWMtNi40IDYuNC05LjkgMTUtOS45IDI0djQuM2MwIDE2LjQgMTMuNiAyOS43IDI5LjkgMjkuN2MxMSAwIDIxLjItNi4yIDI2LjEtMTZsNC04LjFjMi40LTQuOCA3LjQtNy45IDEyLjgtNy45YzQuNSAwIDguNyAyLjEgMTEuNCA1LjdsMTYuMyAyMS43YzIuMSAyLjkgNS41IDQuNSA5LjEgNC41YzguNCAwIDEzLjktOC45IDEwLjEtMTYuNGwtMS4xLTIuM2MtMy41LTcgMC0xNS41IDcuNS0xOGwyMS4yLTcuMWM3LjYtMi41IDEyLjctOS42IDEyLjctMTcuNmMwLTEwLjMgOC4zLTE4LjYgMTguNi0xOC42SDQwMGM4LjggMCAxNiA3LjIgMTYgMTZzLTcuMiAxNi0xNiAxNkgzNzkuM2MtNy4yIDAtMTQuMiAyLjktMTkuMyA4bC00LjcgNC43Yy0yLjEgMi4xLTMuMyA1LTMuMyA4YzAgNi4yIDUuMSAxMS4zIDExLjMgMTEuM2gxMS4zYzYgMCAxMS44IDIuNCAxNiA2LjZsNi41IDYuNWMxLjggMS44IDIuOCA0LjMgMi44IDYuOHMtMSA1LTIuOCA2LjhsLTcuNSA3LjVDMzg2IDI2MiAzODQgMjY2LjkgMzg0IDI3MnMyIDEwIDUuNyAxMy43TDQwOCAzMDRjMTAuMiAxMC4yIDI0LjEgMTYgMzguNiAxNkg0NTRjNi41LTIwLjIgMTAtNDEuNyAxMC02NGMwLTExMS40LTg3LjYtMjAyLjQtMTk3LjctMjA3Ljd6bTE3MiAzMDcuOWMtMy43LTIuNi04LjItNC4xLTEzLTQuMWMtNiAwLTExLjgtMi40LTE2LTYuNkwzOTYgMzMyYy03LjctNy43LTE4LTEyLTI4LjktMTJjLTkuNyAwLTE5LjItMy41LTI2LjYtOS44TDMxNCAyODcuNGMtMTEuNi05LjktMjYuNC0xNS40LTQxLjctMTUuNEgyNTEuNGMtMTIuNiAwLTI1IDMuNy0zNS41IDEwLjdMMTg4LjUgMzAxYy0xNy44IDExLjktMjguNSAzMS45LTI4LjUgNTMuM3YzLjJjMCAxNyA2LjcgMzMuMyAxOC43IDQ1LjNsMTYgMTZjOC41IDguNSAyMCAxMy4zIDMyIDEzLjNIMjQ4YzEzLjMgMCAyNCAxMC43IDI0IDI0YzAgMi41IC40IDUgMS4xIDcuM2M3MS4zLTUuOCAxMzIuNS00Ny42IDE2NS4yLTEwNy4yek0wIDI1NmEyNTYgMjU2IDAgMSAxIDUxMiAwQTI1NiAyNTYgMCAxIDEgMCAyNTZ6TTE4Ny4zIDEwMC43Yy02LjItNi4yLTE2LjQtNi4yLTIyLjYgMGwtMzIgMzJjLTYuMiA2LjItNi4yIDE2LjQgMCAyMi42czE2LjQgNi4yIDIyLjYgMGwzMi0zMmM2LjItNi4yIDYuMi0xNi40IDAtMjIuNnoiLz48L3N2Zz4K',
          panel_third: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMWVtIiB2aWV3Qm94PSIwIDAgNTEyIDUxMiI+PCEtLSEgRm9udCBBd2Vzb21lIEZyZWUgNi40LjIgYnkgQGZvbnRhd2Vzb21lIC0gaHR0cHM6Ly9mb250YXdlc29tZS5jb20gTGljZW5zZSAtIGh0dHBzOi8vZm9udGF3ZXNvbWUuY29tL2xpY2Vuc2UgKENvbW1lcmNpYWwgTGljZW5zZSkgQ29weXJpZ2h0IDIwMjMgRm9udGljb25zLCBJbmMuIC0tPjxwYXRoIGQ9Ik00OTUuOSAxNjYuNmMzLjIgOC43IC41IDE4LjQtNi40IDI0LjZsLTQzLjMgMzkuNGMxLjEgOC4zIDEuNyAxNi44IDEuNyAyNS40cy0uNiAxNy4xLTEuNyAyNS40bDQzLjMgMzkuNGM2LjkgNi4yIDkuNiAxNS45IDYuNCAyNC42Yy00LjQgMTEuOS05LjcgMjMuMy0xNS44IDM0LjNsLTQuNyA4LjFjLTYuNiAxMS0xNCAyMS40LTIyLjEgMzEuMmMtNS45IDcuMi0xNS43IDkuNi0yNC41IDYuOGwtNTUuNy0xNy43Yy0xMy40IDEwLjMtMjguMiAxOC45LTQ0IDI1LjRsLTEyLjUgNTcuMWMtMiA5LjEtOSAxNi4zLTE4LjIgMTcuOGMtMTMuOCAyLjMtMjggMy41LTQyLjUgMy41cy0yOC43LTEuMi00Mi41LTMuNWMtOS4yLTEuNS0xNi4yLTguNy0xOC4yLTE3LjhsLTEyLjUtNTcuMWMtMTUuOC02LjUtMzAuNi0xNS4xLTQ0LTI1LjRMODMuMSA0MjUuOWMtOC44IDIuOC0xOC42IC4zLTI0LjUtNi44Yy04LjEtOS44LTE1LjUtMjAuMi0yMi4xLTMxLjJsLTQuNy04LjFjLTYuMS0xMS0xMS40LTIyLjQtMTUuOC0zNC4zYy0zLjItOC43LS41LTE4LjQgNi40LTI0LjZsNDMuMy0zOS40QzY0LjYgMjczLjEgNjQgMjY0LjYgNjQgMjU2cy42LTE3LjEgMS43LTI1LjRMMjIuNCAxOTEuMmMtNi45LTYuMi05LjYtMTUuOS02LjQtMjQuNmM0LjQtMTEuOSA5LjctMjMuMyAxNS44LTM0LjNsNC43LTguMWM2LjYtMTEgMTQtMjEuNCAyMi4xLTMxLjJjNS45LTcuMiAxNS43LTkuNiAyNC41LTYuOGw1NS43IDE3LjdjMTMuNC0xMC4zIDI4LjItMTguOSA0NC0yNS40bDEyLjUtNTcuMWMyLTkuMSA5LTE2LjMgMTguMi0xNy44QzIyNy4zIDEuMiAyNDEuNSAwIDI1NiAwczI4LjcgMS4yIDQyLjUgMy41YzkuMiAxLjUgMTYuMiA4LjcgMTguMiAxNy44bDEyLjUgNTcuMWMxNS44IDYuNSAzMC42IDE1LjEgNDQgMjUuNGw1NS43LTE3LjdjOC44LTIuOCAxOC42LS4zIDI0LjUgNi44YzguMSA5LjggMTUuNSAyMC4yIDIyLjEgMzEuMmw0LjcgOC4xYzYuMSAxMSAxMS40IDIyLjQgMTUuOCAzNC4zek0yNTYgMzM2YTgwIDgwIDAgMSAwIDAtMTYwIDgwIDgwIDAgMSAwIDAgMTYweiIvPjwvc3ZnPgo='
        }
      },
      accompanying_message: {
        fr: {
          link: '?utm_source=fr-automation-4&utm_medium=email&utm_campaign=automation-fr-4&utm_content=link-support-4'
        },
        en: {
          link: '?utm_source=en-automation-4&utm_medium=email&utm_campaign=automation-en-4&utm_content=link-support-4'
        }
      },
      subscribe_message: {
        fr: {
          link: '?utm_source=fr-automation-5&utm_medium=email&utm_campaign=automation-fr-5&utm_content=link-subscribe'
        },
        en: {
          link: '?utm_source=en-automation-1&utm_medium=email&utm_campaign=automation-en-5&utm_content=link-subscribe'
        }
      }
    },
    network_icons: {
      facebook: "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMWVtIiB2aWV3Qm94PSIwIDAgNTEyIDUxMiI+PCEtLSEgRm9udCBBd2Vzb21lIEZyZWUgNi40LjIgYnkgQGZvbnRhd2Vzb21lIC0gaHR0cHM6Ly9mb250YXdlc29tZS5jb20gTGljZW5zZSAtIGh0dHBzOi8vZm9udGF3ZXNvbWUuY29tL2xpY2Vuc2UgKENvbW1lcmNpYWwgTGljZW5zZSkgQ29weXJpZ2h0IDIwMjMgRm9udGljb25zLCBJbmMuIC0tPjxwYXRoIGQ9Ik01MDQgMjU2QzUwNCAxMTkgMzkzIDggMjU2IDhTOCAxMTkgOCAyNTZjMCAxMjMuNzggOTAuNjkgMjI2LjM4IDIwOS4yNSAyNDVWMzI3LjY5aC02M1YyNTZoNjN2LTU0LjY0YzAtNjIuMTUgMzctOTYuNDggOTMuNjctOTYuNDggMjcuMTQgMCA1NS41MiA0Ljg0IDU1LjUyIDQuODR2NjFoLTMxLjI4Yy0zMC44IDAtNDAuNDEgMTkuMTItNDAuNDEgMzguNzNWMjU2aDY4Ljc4bC0xMSA3MS42OWgtNTcuNzhWNTAxQzQxMy4zMSA0ODIuMzggNTA0IDM3OS43OCA1MDQgMjU2eiIvPjwvc3ZnPgo=",
      linkedin: "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMWVtIiB2aWV3Qm94PSIwIDAgNDQ4IDUxMiI+PCEtLSEgRm9udCBBd2Vzb21lIEZyZWUgNi40LjIgYnkgQGZvbnRhd2Vzb21lIC0gaHR0cHM6Ly9mb250YXdlc29tZS5jb20gTGljZW5zZSAtIGh0dHBzOi8vZm9udGF3ZXNvbWUuY29tL2xpY2Vuc2UgKENvbW1lcmNpYWwgTGljZW5zZSkgQ29weXJpZ2h0IDIwMjMgRm9udGljb25zLCBJbmMuIC0tPjxwYXRoIGQ9Ik00MTYgMzJIMzEuOUMxNC4zIDMyIDAgNDYuNSAwIDY0LjN2MzgzLjRDMCA0NjUuNSAxNC4zIDQ4MCAzMS45IDQ4MEg0MTZjMTcuNiAwIDMyLTE0LjUgMzItMzIuM1Y2NC4zYzAtMTcuOC0xNC40LTMyLjMtMzItMzIuM3pNMTM1LjQgNDE2SDY5VjIwMi4yaDY2LjVWNDE2em0tMzMuMi0yNDNjLTIxLjMgMC0zOC41LTE3LjMtMzguNS0zOC41UzgwLjkgOTYgMTAyLjIgOTZjMjEuMiAwIDM4LjUgMTcuMyAzOC41IDM4LjUgMCAyMS4zLTE3LjIgMzguNS0zOC41IDM4LjV6bTI4Mi4xIDI0M2gtNjYuNFYzMTJjMC0yNC44LS41LTU2LjctMzQuNS01Ni43LTM0LjYgMC0zOS45IDI3LTM5LjkgNTQuOVY0MTZoLTY2LjRWMjAyLjJoNjMuN3YyOS4yaC45YzguOS0xNi44IDMwLjYtMzQuNSA2Mi45LTM0LjUgNjcuMiAwIDc5LjcgNDQuMyA3OS43IDEwMS45VjQxNnoiLz48L3N2Zz4K",
      twitter: "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMWVtIiB2aWV3Qm94PSIwIDAgNDQ4IDUxMiI+PCEtLSEgRm9udCBBd2Vzb21lIEZyZWUgNi40LjIgYnkgQGZvbnRhd2Vzb21lIC0gaHR0cHM6Ly9mb250YXdlc29tZS5jb20gTGljZW5zZSAtIGh0dHBzOi8vZm9udGF3ZXNvbWUuY29tL2xpY2Vuc2UgKENvbW1lcmNpYWwgTGljZW5zZSkgQ29weXJpZ2h0IDIwMjMgRm9udGljb25zLCBJbmMuIC0tPjxwYXRoIGQ9Ik02NCAzMkMyOC43IDMyIDAgNjAuNyAwIDk2VjQxNmMwIDM1LjMgMjguNyA2NCA2NCA2NEgzODRjMzUuMyAwIDY0LTI4LjcgNjQtNjRWOTZjMC0zNS4zLTI4LjctNjQtNjQtNjRINjR6TTM1MS4zIDE5OS4zdjBjMCA4Ni43LTY2IDE4Ni42LTE4Ni42IDE4Ni42Yy0zNy4yIDAtNzEuNy0xMC44LTEwMC43LTI5LjRjNS4zIC42IDEwLjQgLjggMTUuOCAuOGMzMC43IDAgNTguOS0xMC40IDgxLjQtMjhjLTI4LjgtLjYtNTMtMTkuNS02MS4zLTQ1LjVjMTAuMSAxLjUgMTkuMiAxLjUgMjkuNi0xLjJjLTMwLTYuMS01Mi41LTMyLjUtNTIuNS02NC40di0uOGM4LjcgNC45IDE4LjkgNy45IDI5LjYgOC4zYy05LTYtMTYuNC0xNC4xLTIxLjUtMjMuNnMtNy44LTIwLjItNy43LTMxYzAtMTIuMiAzLjItMjMuNCA4LjktMzMuMWMzMi4zIDM5LjggODAuOCA2NS44IDEzNS4yIDY4LjZjLTkuMy00NC41IDI0LTgwLjYgNjQtODAuNmMxOC45IDAgMzUuOSA3LjkgNDcuOSAyMC43YzE0LjgtMi44IDI5LTguMyA0MS42LTE1LjhjLTQuOSAxNS4yLTE1LjIgMjgtMjguOCAzNi4xYzEzLjItMS40IDI2LTUuMSAzNy44LTEwLjJjLTguOSAxMy4xLTIwLjEgMjQuNy0zMi45IDM0Yy4yIDIuOCAuMiA1LjcgLjIgOC41eiIvPjwvc3ZnPgo="
    }
  }
